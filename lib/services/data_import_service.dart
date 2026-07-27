import 'package:drift/drift.dart' as d;
import '../cloud/sync/change_tracker.dart';
import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import '../data/repositories/transaction_repository.dart'
    show
        BatchAttachmentData,
        TransactionRelationsUpdateBySyncIdData,
        TransactionUpdateBySyncIdData;
import 'currency/rate_math.dart';
import 'system/logger_service.dart';

/// 统一的数据导入服务
///
/// 用于CSV导入和云端恢复，确保两者使用相同的导入逻辑

// --- 导入数据模型 ---

/// 导入账户数据
class ImportAccount {
  final String name;
  final String? type;
  final String? currency;
  final double? initialBalance;

  const ImportAccount({
    required this.name,
    this.type,
    this.currency,
    this.initialBalance,
  });
}

/// 导入分类数据
class ImportCategory {
  final String name;
  final String kind; // 'income' or 'expense'
  final int level; // 1 or 2
  final int sortOrder; // 排序顺序
  final String? icon;
  final String? parentName; // 二级分类的父分类名称
  final String? iconType; // 图标类型: material / custom / community
  final String? customIconPath; // 自定义图标路径
  final String? communityIconId; // 社区图标ID

  const ImportCategory({
    required this.name,
    required this.kind,
    this.level = 1,
    this.sortOrder = 0,
    this.icon,
    this.parentName,
    this.iconType,
    this.customIconPath,
    this.communityIconId,
  });
}

/// 导入标签数据
class ImportTag {
  final String name;
  final String? color;

  const ImportTag({
    required this.name,
    this.color,
  });
}

/// 导入附件数据
class ImportAttachment {
  final String fileName;
  final String? originalName;
  final int? fileSize;
  final int? width;
  final int? height;
  final int sortOrder;
  final String? cloudFileId;
  final String? cloudSha256;

  const ImportAttachment({
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

/// 导入交易数据
class ImportTransaction {
  final String type; // 'income', 'expense', 'transfer'
  final double amount;
  final String? categoryName;
  final String? categoryKind;
  final DateTime happenedAt;
  final String? note;
  final String? accountName; // 普通账户（收入/支出）
  final String? fromAccountName; // 转出账户（转账）
  final String? toAccountName; // 转入账户（转账）
  final List<String>? tagNames; // 标签名称列表
  final bool tagNamesPresent; // 是否由权威 payload 提供标签集合
  final int? categoryId; // 预解析的分类ID（优先于categoryName）
  final List<ImportAttachment>? attachments; // 附件元数据列表
  final bool attachmentsPresent; // 缺键=legacy preserve；present empty=clear
  final String? syncId; // 跨设备同步唯一标识
  /// v30 多币种:CSV 币种列(反馈10)。null → 账户币种/账本本位币兜底。
  final String? currencyCode;

  /// v31 专项预算关联(仅 expense 有效,指向 budgets.type='project' 的 syncId)。
  /// v6 快照没这个键;v7 快照全量携带,unlinked 时为 null。
  final String? projectBudgetSyncId;

  /// v31 tri-state marker:payload 中是否**出现过**该键。
  /// - false → v6 快照 / 老 CSV / 未支持此字段的对端 → 恢复期应"保留本地关联,
  ///   不清除"(sync_diff 里等价于 Value.absent());
  /// - true 且值 == null → 显式清除关联;
  /// - true 且值 != null → 关联到该 syncId。
  ///
  /// 这个 flag 由 [parseJsonToImportData] 按键存在性设置。Reviewer Mn5 报告的
  /// "v6 备份重新导入静默清空 project 链接" 由此修复。
  final bool projectBudgetSyncIdPresent;

  const ImportTransaction({
    required this.type,
    required this.amount,
    this.currencyCode,
    this.categoryName,
    this.categoryKind,
    required this.happenedAt,
    this.note,
    this.accountName,
    this.fromAccountName,
    this.toAccountName,
    this.tagNames,
    bool? tagNamesPresent,
    this.categoryId,
    this.attachments,
    bool? attachmentsPresent,
    this.syncId,
    this.projectBudgetSyncId,
    this.projectBudgetSyncIdPresent = false,
  })  : tagNamesPresent = tagNamesPresent ?? tagNames != null,
        attachmentsPresent = attachmentsPresent ?? attachments != null;
}

/// v31 导入专项预算数据(仅 v7 快照使用)。
///
/// 与 [ImportTransaction] 同为 top-level 阵列的一项,恢复顺序上必须在
/// transactions 之前 —— 否则 `projectBudgetSyncId` 指向的 project 行还没建。
class ImportBudget {
  final String syncId;
  final String type; // 'total' / 'category' / 'project'
  final double amount;
  final String period;
  final int startDay;
  final bool enabled;
  final String? categoryName; // 仅 type='category' 需要,通过 name resolve
  // project 专有字段
  final String? name;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool excludeFromMonthlyTotal;
  final String status;

  const ImportBudget({
    required this.syncId,
    required this.type,
    required this.amount,
    this.period = 'monthly',
    this.startDay = 1,
    this.enabled = true,
    this.categoryName,
    this.name,
    this.startAt,
    this.endAt,
    this.excludeFromMonthlyTotal = false,
    this.status = 'active',
  });
}

/// 统一的导入数据格式
class ImportData {
  final List<ImportAccount> accounts;
  final List<ImportCategory> categories;
  final List<ImportTag> tags;
  final List<ImportTransaction> transactions;

  /// v31: v7 快照新增的 top-level `budgets`(不影响 v6 快照)。
  final List<ImportBudget> budgets;

  /// 账本名称（可选，用于更新账本信息）
  final String? ledgerName;

  /// 货币（可选，用于更新账本信息）
  final String? currency;

  const ImportData({
    this.accounts = const [],
    this.categories = const [],
    this.tags = const [],
    this.transactions = const [],
    this.budgets = const [],
    this.ledgerName,
    this.currency,
  });
}

/// 导入结果
class ImportResult {
  final int inserted;
  final int failed;

  const ImportResult({
    required this.inserted,
    required this.failed,
  });
}

// --- 数据导入服务 ---

/// 通用数据导入服务
///
/// 提供统一的导入逻辑，支持：
/// - 账户创建（全局按名称去重）
/// - 分类创建（先一级后二级）
/// - 标签创建
/// - 交易插入（批量写入）
/// - 标签关联
class DataImportService {
  /// 导入数据到指定账本
  ///
  /// [repo] - 数据仓库
  /// [ledgerId] - 目标账本ID
  /// [data] - 导入数据
  /// [defaultCurrency] - 默认货币（用于创建账户）
  /// [onProgress] - 进度回调 (done, total)
  /// [recordChanges] - 默认 true,会调 repo.insertTransactionsBatch 时登记
  ///   changeTracker。FullPull 路径传 false,避免"从云端拉下来的数据又反向推
  ///   回去"。
  Future<ImportResult> importData(
    BaseRepository repo,
    int ledgerId,
    ImportData data, {
    String defaultCurrency = 'CNY',
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
    // v31 恢复期专用:调用方(fullPull / manual import)显式传入 changeTracker,
    // 让 importBudgets 能在 recordChanges=true 时按 payload syncId 手动记 change,
    // 保持 local_changes.entity_sync_id 与 budgets.sync_id 一致。传 null 时
    // 一律不记 change(相当于强制 recordChanges=false for budgets 分支)。
    ChangeTracker? changeTracker,
  }) async {
    // 1. 更新账本信息（如果提供）
    if (data.ledgerName != null || data.currency != null) {
      try {
        await repo.updateLedger(
          id: ledgerId,
          name: data.ledgerName,
          currency: data.currency,
        );
      } catch (_) {}
    }

    // 2. 导入账户
    final accountNameToId = await importAccounts(
      repo,
      data.accounts,
      defaultCurrency: data.currency ?? defaultCurrency,
    );

    // 3. 导入分类
    final categoryCache = await importCategories(repo, data.categories);

    // 4. 导入标签
    final tagNameToId = await importTags(repo, data.tags);

    // 4.5 v31: 导入预算(仅 v7 快照携带 top-level `budgets`;v6 快照及旧路径
    //     此数组为空 → no-op)。顺序**必须**先于 transactions —— items 里的
    //     projectBudgetSyncId 引用的是这里插入的 project 行。recordChanges
    //     一路透传,让 fullPull 走静默恢复 / 用户手动导入走 create change。
    if (data.budgets.isNotEmpty) {
      await importBudgets(
        repo,
        ledgerId,
        data.budgets,
        categoryCache: categoryCache,
        changeTracker: changeTracker,
        recordChanges: recordChanges,
      );
    }

    // 5. 导入交易
    final result = await importTransactions(
      repo,
      ledgerId,
      data.transactions,
      accountNameToId: accountNameToId,
      categoryCache: categoryCache,
      tagNameToId: tagNameToId,
      onProgress: onProgress,
      recordChanges: recordChanges,
    );

    return result;
  }

  /// v31: 恢复导入包里的专项/总/分类预算。fullPull / v7 snapshot import 前置
  /// 步骤;必须在 transactions 之前调用。
  ///
  /// **保留 payload 的 syncId** —— 通过 [BudgetRepository.restoreBudgetBySyncId]
  /// 走"跳过 UUID 生成 + 跳过 change tracker"的低层路径,再由本方法在
  /// [recordChanges]=true 时手动 recordLedgerChange,syncId 和 payload 里的
  /// 完全一致,避免 review 里 BL1 那种"local_changes 记的是临时 UUID,
  /// budgets 表存的是真实 UUID"的双端分裂。
  ///
  /// 幂等:先查同 syncId(不限 type),已有 → update-in-place;没有 → insert。
  /// fullPull 反复恢复也不会 duplicate,total/category/project 都覆盖。
  ///
  /// [recordChanges]=false 时不登记 changeTracker;fullPull 走这个路径,
  /// 避免"从云端拉下来的又被反向 push 回去"。
  ///
  /// public — sync_diff_service 可复用。
  Future<int> importBudgets(
    BaseRepository repo,
    int ledgerId,
    List<ImportBudget> budgets, {
    Map<String, int> categoryCache = const {},
    ChangeTracker? changeTracker,
    bool recordChanges = true,
  }) async {
    if (budgets.isEmpty) return 0;
    logger.info('BudgetImport',
        '开始导入预算: ${budgets.length} 条 (recordChanges=$recordChanges)');
    int applied = 0;
    for (final b in budgets) {
      try {
        if (b.type == 'project' &&
            (!b.amount.isFinite ||
                b.amount <= 0 ||
                (b.name?.trim().isEmpty ?? true) ||
                b.startAt == null ||
                b.endAt == null ||
                !b.startAt!.isBefore(b.endAt!) ||
                (b.status != 'planned' &&
                    b.status != 'active' &&
                    b.status != 'archived'))) {
          logger.warning('BudgetImport', '专项预算 ${b.syncId} 字段不合法，跳过恢复');
          continue;
        }
        // 解析 category 预算的 categoryId(通过 name 查缓存;找不到不 block)。
        int? categoryId;
        if (b.type == 'category' && (b.categoryName?.isNotEmpty ?? false)) {
          for (final entry in categoryCache.entries) {
            final parts = entry.key.split('|');
            if (parts.length == 2 && parts[1] == b.categoryName) {
              categoryId = entry.value;
              break;
            }
          }
        }
        final wasExisting = (await repo.getBudgetBySyncId(b.syncId)) != null;
        // 直接以 payload syncId 走 restore(upsert)。**不**经过 createBudget
        // wrapper,因此不会记 change,也不会分配临时 UUID。
        final localId = await repo.restoreBudgetBySyncId(
          syncId: b.syncId,
          ledgerId: ledgerId,
          type: b.type,
          categoryId: categoryId,
          amount: b.amount,
          period: b.period,
          startDay: b.startDay,
          enabled: b.enabled,
          name: b.name,
          startAt: b.startAt,
          endAt: b.endAt,
          excludeFromMonthlyTotal: b.excludeFromMonthlyTotal,
          status: b.status,
        );
        // recordChanges=true(用户手动导入 / CSV import)才登记 change;此时
        // local_changes.entity_sync_id 用的就是 payload 里的 syncId,与 push 时
        // 从 budgets 表反查出来的 syncId 完全一致 —— 不再有 BL1 的分裂。
        if (recordChanges && changeTracker != null) {
          await changeTracker.recordLedgerChange(
            entityType: 'budget',
            entityId: localId,
            entitySyncId: b.syncId,
            ledgerId: ledgerId,
            action: wasExisting ? 'update' : 'create',
          );
        }
        applied++;
      } catch (e, st) {
        logger.warning('BudgetImport', '预算 ${b.syncId} 导入失败,跳过: $e\n$st');
      }
    }
    logger.info('BudgetImport', '预算导入完成: 应用 $applied / ${budgets.length}');
    return applied;
  }

  /// 导入账户(全局按名称去重)。public — sync_diff_service 也复用,避免维护两套。
  Future<Map<String, int>> importAccounts(
      BaseRepository repo, List<ImportAccount> accounts,
      {String defaultCurrency = 'CNY'}) async {
    final accountNameToId = <String, int>{};

    if (accounts.isEmpty) return accountNameToId;
    logger.info('AccountImport', '开始导入账户: ${accounts.length} 个');
    final sw = Stopwatch()..start();
    int created = 0;

    try {
      final existingAccounts = await repo.getAllAccounts();
      for (final acc in existingAccounts) {
        accountNameToId[acc.name] = acc.id;
      }

      for (final acc in accounts) {
        if (!accountNameToId.containsKey(acc.name)) {
          final id = await repo.createAccount(
            ledgerId: 0, // 账户独立,不绑定账本
            name: acc.name,
            type: acc.type ?? 'cash',
            currency: acc.currency ?? defaultCurrency,
            initialBalance: acc.initialBalance ?? 0.0,
          );
          accountNameToId[acc.name] = id;
          created++;
        }
      }
      logger.info('AccountImport',
          '账户导入完成: 新增=$created 已存在=${accounts.length - created} 耗时=${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      logger.error('AccountImport', '账户导入失败', e, st);
    }

    return accountNameToId;
  }

  /// 导入分类(先一级后二级)。public — sync_diff_service 复用。
  Future<Map<String, int>> importCategories(
    BaseRepository repo,
    List<ImportCategory> categories,
  ) async {
    final categoryCache = <String, int>{}; // key: kind|name -> id

    if (categories.isEmpty) return categoryCache;
    logger.info('CategoryImport', '开始导入分类: ${categories.length} 个');
    final sw = Stopwatch()..start();
    int created = 0;

    try {
      // 获取所有现有分类
      final existingExpense = await repo.getTopLevelCategories('expense');
      final existingIncome = await repo.getTopLevelCategories('income');
      final existingCategoryMap = <String, int>{};

      for (final cat in [...existingExpense, ...existingIncome]) {
        existingCategoryMap['${cat.kind}|${cat.name}'] = cat.id;
        // 获取子分类
        final subCats = await repo.getSubCategories(cat.id);
        for (final sub in subCats) {
          existingCategoryMap['${sub.kind}|${sub.name}'] = sub.id;
        }
      }

      // 分离一级和二级分类
      final level1 = categories
          .where((c) => c.level == 1 || c.parentName == null)
          .toList();
      final level2 = categories
          .where((c) => c.level == 2 && c.parentName != null)
          .toList();

      // 导入一级分类
      for (final cat in level1) {
        final key = '${cat.kind}|${cat.name}';
        if (existingCategoryMap.containsKey(key)) {
          categoryCache[key] = existingCategoryMap[key]!;
        } else {
          final id = await repo.createCategory(
            name: cat.name,
            kind: cat.kind,
            icon: cat.icon,
            sortOrder: cat.sortOrder,
          );
          categoryCache[key] = id;
          created++;

          // 如果有自定义图标信息，更新图标
          if (cat.iconType != null && cat.iconType != 'material') {
            await repo.updateCategoryIcon(
              id,
              iconType: cat.iconType!,
              icon: cat.icon,
              customIconPath: cat.customIconPath,
              communityIconId: cat.communityIconId,
            );
          }
        }
      }

      // 导入二级分类
      for (final cat in level2) {
        final key = '${cat.kind}|${cat.name}';
        if (existingCategoryMap.containsKey(key)) {
          categoryCache[key] = existingCategoryMap[key]!;
        } else {
          // 查找父分类ID
          final parentKey = '${cat.kind}|${cat.parentName}';
          final parentId = categoryCache[parentKey];
          if (parentId != null) {
            final id = await repo.createSubCategory(
              parentId: parentId,
              name: cat.name,
              kind: cat.kind,
              icon: cat.icon,
              sortOrder: cat.sortOrder,
            );
            categoryCache[key] = id;

            // 如果有自定义图标信息，更新图标
            if (cat.iconType != null && cat.iconType != 'material') {
              await repo.updateCategoryIcon(
                id,
                iconType: cat.iconType!,
                icon: cat.icon,
                customIconPath: cat.customIconPath,
                communityIconId: cat.communityIconId,
              );
            }
          }
        }
      }
      logger.info('CategoryImport',
          '分类导入完成: 新增=$created 已存在=${categories.length - created} 耗时=${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      logger.error('CategoryImport', '分类导入失败', e, st);
    }

    return categoryCache;
  }

  /// 导入标签。public — sync_diff_service 复用。
  Future<Map<String, int>> importTags(
    BaseRepository repo,
    List<ImportTag> tags,
  ) async {
    final tagNameToId = <String, int>{};

    if (tags.isEmpty) return tagNameToId;

    logger.info('TagImport', '开始导入标签: ${tags.length} 个');
    final sw = Stopwatch()..start();
    int created = 0;
    int updated = 0;

    try {
      final existingTags = await repo.getAllTags();
      final existingTagMap = <String, Tag>{};
      for (final tag in existingTags) {
        tagNameToId[tag.name] = tag.id;
        existingTagMap[tag.name] = tag;
      }

      // 单条 await 循环 — 标签量通常小(<100),没批量接口暂保持,但去掉 per-row
      // INFO 日志:N 个标签会打 3N 条 INFO,把 logger 队列冲爆,导致后续 import
      // 阶段的日志被淹没,用户感知"日志不全"。
      for (final tag in tags) {
        if (!tagNameToId.containsKey(tag.name)) {
          final id = await repo.createTag(name: tag.name, color: tag.color);
          tagNameToId[tag.name] = id;
          created++;
        } else if (tag.color != null) {
          final existingTag = existingTagMap[tag.name];
          if (existingTag != null && existingTag.color != tag.color) {
            await repo.updateTag(existingTag.id, color: tag.color);
            updated++;
          }
        }
      }
      logger.info('TagImport',
          '标签导入完成: 新增=$created 更新=$updated 耗时=${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      logger.error('TagImport', '标签导入失败', e, st);
    }

    return tagNameToId;
  }

  /// 导入交易(统一 batch 路径,tag/attachment 跟 tx 一起 batch insert)
  ///
  /// **历史**:之前"有标签/附件"的 tx 走单条 await 路径,
  ///   `insertTransactionCompanion` → `updateTransactionTags` → `createAttachment`
  /// 各开自己的 BEGIN/COMMIT,N+1 + 嵌套事务双重放大,1 万条带标签数据要几十
  /// 分钟。
  ///
  /// **现在**:全部走 `insertTransactionsBatchWithRelations`,500 条 / 批,
  /// 一个 db.transaction 内 batch insert tx + tag + attachment + local_changes,
  /// 把 N 次 BEGIN/COMMIT/fsync 折叠成 1 次。
  ///
  /// public — sync_diff_service 复用。
  Future<ImportResult> importTransactions(
    BaseRepository repo,
    int ledgerId,
    List<ImportTransaction> transactions, {
    required Map<String, int> accountNameToId,
    required Map<String, int> categoryCache,
    required Map<String, int> tagNameToId,
    void Function(int done, int total)? onProgress,
    bool recordChanges = true,
  }) async {
    int inserted = 0;
    int failed = 0;
    int processed = 0;
    final total = transactions.length;
    logger.info('TxImport', '开始导入交易: $total 条 (recordChanges=$recordChanges)');

    // v30 交易级多币种(02 §六导入修补):批量预取本位币/账户币种/有效汇率,
    // 逐条填 currencyCode + nativeAmount,不再落 NULL(NULL 行 L11 检测
    // 需 join 兜底,且外币账户导入折算会静默 1:1)。
    final ledger = await repo.getLedgerById(ledgerId);
    final ledgerBase =
        ((ledger?.currency.isNotEmpty ?? false) ? ledger!.currency : 'CNY')
            .toUpperCase();
    final accountCurrencyById = <int, String>{
      for (final a in await repo.getAllAccounts())
        a.id: (a.currency.isNotEmpty ? a.currency : ledgerBase).toUpperCase(),
    };
    Map<String, EffectiveRate> importRates = const {};
    try {
      final autos = await repo.getLatestAutoRates(ledgerBase);
      final overrides = await repo.getOverrides(ledgerBase);
      importRates = mergeEffectiveRates(
        autoRates: [
          for (final r in autos)
            (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
        ],
        overrides: [
          for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
        ],
      );
    } catch (e) {
      logger.warning('TxImport', '导入取汇率失败,外币交易将按 1:1 待 L11 捞回: $e');
    }
    final overallSw = Stopwatch()..start();

    const batchSize = 500;
    // 批次缓冲:tx 列表 + 按 batch 内 index 索引的关联数据
    final batchTx = <TransactionsCompanion>[];
    final batchTagsByIndex = <int, List<int>>{};
    final batchAttachmentsByIndex = <int, List<BatchAttachmentData>>{};

    final localCategoryCache = Map<String, int>.from(categoryCache);

    // 把当前缓冲 flush 到 repo。捕获异常时整批算 failed,继续下一批。
    Future<void> flush() async {
      if (batchTx.isEmpty) return;
      final size = batchTx.length;
      final batchSw = Stopwatch()..start();
      try {
        final ids = await repo.insertTransactionsBatchWithRelations(
          transactions: List.of(batchTx),
          tagIdsByIndex: Map.of(batchTagsByIndex),
          attachmentsByIndex: Map.of(batchAttachmentsByIndex),
          recordChanges: recordChanges,
        );
        inserted += ids.length;
        logger.info('TxImport',
            'flush 批次: size=$size 耗时=${batchSw.elapsedMilliseconds}ms 累计=${processed + size}/$total');
      } catch (e, st) {
        logger.error('TxImport', '批次 flush 失败,本批 $size 条算 failed', e, st);
        failed += size;
      }
      processed += size;
      batchTx.clear();
      batchTagsByIndex.clear();
      batchAttachmentsByIndex.clear();
      if (onProgress != null) onProgress(processed, total);
    }

    for (final tx in transactions) {
      if (tx.projectBudgetSyncId != null) {
        // Project links are valid only for expense transactions. Reject before
        // buffering so one malformed item cannot poison the whole batch.
        if (tx.type != 'expense') {
          logger.warning(
              'TxImport',
              'transaction ${tx.syncId ?? '<new>'} 的 projectBudgetSyncId '
                  '只能用于 expense，跳过');
          failed++;
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }
        try {
          final project =
              await repo.getProjectBudgetBySyncId(tx.projectBudgetSyncId!);
          if (project == null || project.ledgerId != ledgerId) {
            logger.warning(
                'TxImport',
                'transaction ${tx.syncId ?? '<new>'} 的 projectBudgetSyncId '
                    '未解析为同账本 project，跳过');
            failed++;
            processed++;
            if (onProgress != null) onProgress(processed, total);
            continue;
          }
        } catch (e, st) {
          logger.error(
              'TxImport',
              'transaction ${tx.syncId ?? '<new>'} 的 projectBudgetSyncId '
                  '查询失败，跳过',
              e,
              st);
          failed++;
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }
      }
      // 解析分类ID
      int? categoryId;
      if (tx.categoryId != null) {
        categoryId = tx.categoryId;
      } else if (tx.categoryName != null && tx.categoryKind != null) {
        final key = '${tx.categoryKind}|${tx.categoryName}';
        categoryId = localCategoryCache[key];
        if (categoryId == null && tx.type != 'transfer') {
          try {
            categoryId = await repo.upsertCategory(
              name: tx.categoryName!,
              kind: tx.categoryKind!,
            );
            localCategoryCache[key] = categoryId;
          } catch (_) {}
        }
      }

      // 解析账户ID
      int? accountId;
      int? toAccountId;
      if (tx.type == 'transfer') {
        if (tx.fromAccountName != null) {
          accountId = accountNameToId[tx.fromAccountName];
          if (accountId == null) {
            failed++;
            processed++;
            continue;
          }
        }
        if (tx.toAccountName != null) {
          toAccountId = accountNameToId[tx.toAccountName];
          if (toAccountId == null) {
            failed++;
            processed++;
            continue;
          }
        }
      } else {
        if (tx.accountName != null) {
          accountId = accountNameToId[tx.accountName];
        }
      }

      // 解析标签ID — toSet().toList() 去重,因为底层 batch insert 不查重
      final tagIds = <int>[];
      if (tx.tagNames != null) {
        for (final tagName in tx.tagNames!) {
          var tagId = tagNameToId[tagName];
          if (tagId == null) {
            try {
              final existingTag = await repo.getTagByName(tagName);
              if (existingTag != null) {
                tagId = existingTag.id;
              } else {
                tagId = await repo.createTag(name: tagName);
              }
              tagNameToId[tagName] = tagId;
            } catch (_) {}
          }
          if (tagId != null) {
            tagIds.add(tagId);
          }
        }
      }
      final uniqueTagIds = tagIds.toSet().toList();

      // v30:交易币种 = CSV 币种列(显式,反馈10)?? 账户币种 ?? 本位币;
      // 折算快照同币种 = amount,外币按有效汇率,取不到 = amount(L11 可捞回)。
      final txCurrency =
          ((tx.currencyCode?.isNotEmpty ?? false) ? tx.currencyCode! : null) ??
              (accountId != null ? accountCurrencyById[accountId] : null) ??
              ledgerBase;
      final txNative = txCurrency == ledgerBase
          ? tx.amount
          : (computeNativeAmount(
                  amount: tx.amount,
                  accountCurrency: txCurrency,
                  ledgerBase: ledgerBase,
                  rates: importRates) ??
              tx.amount);

      // 全量恢复不是 append:同 syncId 已存在时原地更新，避免重复 transaction。
      // project link 的 tri-state 由 batch update 保持：v6 缺键 → absent/保留；
      // v7 显式 null → 清除；非空值 → 更新（引用校验由上层恢复顺序保证）。
      if (tx.syncId != null) {
        try {
          if (await repo.getTransactionBySyncId(tx.syncId!) != null) {
            final updatedId = await repo.updateTransactionWithRelationsBySyncId(
              TransactionRelationsUpdateBySyncIdData(
                transaction: TransactionUpdateBySyncIdData(
                  syncId: tx.syncId!,
                  type: tx.type,
                  amount: tx.amount,
                  categoryId: tx.type == 'transfer' ? null : categoryId,
                  accountId: accountId,
                  toAccountId: toAccountId,
                  happenedAt: tx.happenedAt,
                  note: tx.note,
                  projectBudgetSyncId: tx.projectBudgetSyncIdPresent
                      ? d.Value(tx.projectBudgetSyncId)
                      : null,
                ),
                tagIds: tx.tagNamesPresent ? uniqueTagIds : null,
                attachments: tx.attachmentsPresent
                    ? (tx.attachments ?? const <ImportAttachment>[])
                        .map((attachment) => BatchAttachmentData(
                              fileName: attachment.fileName,
                              originalName: attachment.originalName,
                              fileSize: attachment.fileSize,
                              width: attachment.width,
                              height: attachment.height,
                              sortOrder: attachment.sortOrder,
                              cloudFileId: attachment.cloudFileId,
                              cloudSha256: attachment.cloudSha256,
                            ))
                        .toList()
                    : null,
              ),
              recordChanges: recordChanges,
            );
            if (updatedId == null) {
              throw StateError(
                  'existing transaction disappeared: ${tx.syncId}');
            }
            inserted++;
            processed++;
            if (onProgress != null) onProgress(processed, total);
            continue;
          }
        } catch (e, st) {
          logger.error(
              'TxImport', 'existing transaction ${tx.syncId} 更新失败，跳过', e, st);
          failed++;
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }
      }

      // 构建交易记录
      final txCompanion = TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: tx.type,
        amount: tx.amount,
        categoryId: d.Value(tx.type == 'transfer' ? null : categoryId),
        accountId: d.Value(accountId),
        toAccountId: d.Value(toAccountId),
        happenedAt: d.Value(tx.happenedAt),
        note: d.Value(tx.note),
        syncId: d.Value(tx.syncId),
        currencyCode: d.Value(txCurrency),
        nativeAmount: d.Value(txNative),
        // v31 tri-state:v7 payload 显式带键 → 写入(null=未关联;string=关联);
        // v6 payload 缺键 → Value.absent(),让 DB 默认值 NULL 生效(insert 场景
        // 本来就是新行,不存在"保留本地关联"问题;但保持语义一致)。
        projectBudgetSyncId: tx.projectBudgetSyncIdPresent
            ? d.Value(tx.projectBudgetSyncId)
            : const d.Value.absent(),
      );

      final indexInBatch = batchTx.length;
      batchTx.add(txCompanion);
      if (uniqueTagIds.isNotEmpty) {
        batchTagsByIndex[indexInBatch] = uniqueTagIds;
      }
      if (tx.attachments != null && tx.attachments!.isNotEmpty) {
        batchAttachmentsByIndex[indexInBatch] = tx.attachments!
            .map((a) => BatchAttachmentData(
                  fileName: a.fileName,
                  originalName: a.originalName,
                  fileSize: a.fileSize,
                  width: a.width,
                  height: a.height,
                  sortOrder: a.sortOrder,
                  cloudFileId: a.cloudFileId,
                  cloudSha256: a.cloudSha256,
                ))
            .toList();
      }

      if (batchTx.length >= batchSize) {
        await flush();
      }
    }

    // 刷剩余
    await flush();

    logger.info('TxImport',
        '交易导入完成: 总数=$total 成功=$inserted 失败=$failed 总耗时=${overallSw.elapsedMilliseconds}ms');
    return ImportResult(inserted: inserted, failed: failed);
  }
}

/// 全局单例
final dataImportService = DataImportService();
