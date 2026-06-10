import 'dart:convert';
import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import '../services/data_import_service.dart';
import '../services/system/logger_service.dart';

/// 账本交易数据的 JSON 导入导出工具
///
/// 用于云同步时序列化和反序列化交易数据

// --- 字符串清理 ---

/// 清理字符串中的控制字符，防止 JSON 解析错误
String _sanitizeString(String? input) {
  if (input == null) return '';
  // 移除所有控制字符（ASCII 0-31，除了常见的制表符、换行符等）
  // 并替换换行符和制表符为空格
  return input
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\t', ' ')
      .trim();
}

// --- 导出 ---

/// 导出账本交易数据为 JSON 字符串
///
/// [db] - 数据库实例
/// [ledgerId] - 账本ID
///
/// 返回包含以下字段的 JSON：
/// - version: 数据格式版本（当前为4）
/// - exportedAt: 导出时间戳
/// - ledgerId: 账本ID
/// - ledgerName: 账本名称
/// - currency: 货币
/// - count: 交易条数
/// - accounts: 账户列表（name, type, currency, initialBalance）
/// - categories: 分类列表（name, kind, level, icon, parentName）
/// - tags: 标签列表（name, color）
/// - items: 交易明细（type, amount, categoryName, categoryKind, happenedAt, note, tags）
Future<String> exportTransactionsJson(BeeDatabase db, int ledgerId) async {
  logger.debug('TransactionsJson', '开始导出账本 $ledgerId');

  final txs = await (db.select(db.transactions)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();

  logger.debug('TransactionsJson', '账本 $ledgerId 共有 ${txs.length} 条交易');

  // 稳定排序，避免不同平台/查询导致顺序差异
  txs.sort((a, b) {
    final c = a.happenedAt.compareTo(b.happenedAt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });

  // 获取所有交易的标签（批量查询）
  final txIds = txs.map((t) => t.id).toList();
  final tagsMap = <int, List<Tag>>{}; // transactionId -> tags
  final allUsedTags = <int, Tag>{}; // tagId -> tag（用于导出标签列表）

  if (txIds.isNotEmpty) {
    // 批量查询所有交易的标签关联
    final tagRelations = await (db.select(db.transactionTags)
          ..where((tt) => tt.transactionId.isIn(txIds)))
        .get();

    // 获取所有使用的标签ID
    final usedTagIds = tagRelations.map((r) => r.tagId).toSet();
    if (usedTagIds.isNotEmpty) {
      final tags = await (db.select(db.tags)
            ..where((t) => t.id.isIn(usedTagIds.toList())))
          .get();
      for (final tag in tags) {
        allUsedTags[tag.id] = tag;
      }

      // 构建 transactionId -> tags 映射
      for (final rel in tagRelations) {
        final tag = allUsedTags[rel.tagId];
        if (tag != null) {
          tagsMap.putIfAbsent(rel.transactionId, () => []).add(tag);
        }
      }
    }
  }

  // Map categoryId -> name/kind for used categories
  final usedCatIds = txs.map((t) => t.categoryId).whereType<int>().toSet();
  final cats = <int, Map<String, dynamic>>{};
  final allCategoriesSet = <int>{}; // 存储所有相关分类ID（包括父分类）

  for (final cid in usedCatIds) {
    final c = await (db.select(db.categories)..where((c) => c.id.equals(cid)))
        .getSingleOrNull();
    if (c != null) {
      final sanitizedName = _sanitizeString(c.name);
      cats[cid] = {"name": sanitizedName, "kind": c.kind};
      allCategoriesSet.add(cid);

      // 如果是二级分类，也需要导出其父分类
      if (c.level == 2 && c.parentId != null) {
        allCategoriesSet.add(c.parentId!);
      }
    }
  }

  // v1.15.0: 导出该账本交易中使用的账户（包括转账的toAccountId）
  // 需要在导出 items 之前查询，以便添加账户名称
  final usedAccountIds = <int>{};
  for (final t in txs) {
    if (t.accountId != null) usedAccountIds.add(t.accountId!);
    if (t.toAccountId != null) usedAccountIds.add(t.toAccountId!);
  }
  final accounts = <Account>[];
  final accountIdToName = <int, String>{}; // 账户ID -> 名称映射
  for (final aid in usedAccountIds) {
    final a = await (db.select(db.accounts)..where((a) => a.id.equals(aid)))
        .getSingleOrNull();
    if (a != null) {
      accounts.add(a);
      accountIdToName[a.id] = _sanitizeString(a.name);
    }
  }
  final accountItems = accounts
      .map((a) => {
            'name': _sanitizeString(a.name),
            'type': a.type,
            'currency': a.currency,
            'initialBalance': a.initialBalance,
          })
      .toList();

  final items = txs.map((t) {
    // 安全获取分类信息（分类可能已被删除）
    final catInfo = t.categoryId != null ? cats[t.categoryId] : null;

    // 记录分类缺失的交易（用于排查数据问题）
    if (t.categoryId != null && catInfo == null) {
      logger.warning('TransactionsJson',
        '交易 ${t.id} 引用了不存在的分类 ${t.categoryId}, '
        'amount=${t.amount}, note=${t.note}, happenedAt=${t.happenedAt}');
    }

    final item = <String, dynamic>{
      'type': t.type,
      'amount': t.amount,
      'categoryName': catInfo?['name'],
      'categoryKind': catInfo?['kind'],
      'happenedAt': t.happenedAt.toUtc().toIso8601String(),
      'note': _sanitizeString(t.note),
      if (t.syncId != null) 'syncId': t.syncId,
    };

    // 添加账户信息
    if (t.type == 'transfer') {
      // 转账：添加转出账户和转入账户
      if (t.accountId != null) {
        item['fromAccountName'] = accountIdToName[t.accountId];
      }
      if (t.toAccountId != null) {
        item['toAccountName'] = accountIdToName[t.toAccountId];
      }
    } else {
      // 收入或支出：添加账户
      if (t.accountId != null) {
        item['accountName'] = accountIdToName[t.accountId];
      }
    }

    // 添加标签（逗号分隔的标签名称）
    final txTags = tagsMap[t.id];
    if (txTags != null && txTags.isNotEmpty) {
      item['tags'] = txTags.map((tag) => _sanitizeString(tag.name)).join(',');
    }

    return item;
  }).toList();

  // v1.20.0: 导出附件元数据
  final attachmentsMap = <int, List<Map<String, dynamic>>>{}; // transactionId -> attachments
  if (txIds.isNotEmpty) {
    final allAttachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .get();
    for (final a in allAttachments) {
      final attMap = <String, dynamic>{
        'fileName': a.fileName,
        'originalName': a.originalName,
        'fileSize': a.fileSize,
        'width': a.width,
        'height': a.height,
        'sortOrder': a.sortOrder,
      };
      if (a.cloudFileId != null) attMap['cloudFileId'] = a.cloudFileId;
      if (a.cloudSha256 != null) attMap['cloudSha256'] = a.cloudSha256;
      attachmentsMap.putIfAbsent(a.transactionId, () => []).add(attMap);
    }
  }

  // 将附件信息添加到对应的交易 item 中
  for (int i = 0; i < txs.length; i++) {
    final txId = txs[i].id;
    if (attachmentsMap.containsKey(txId)) {
      items[i]['attachments'] = attachmentsMap[txId];
    }
  }

  // ledger meta
  final ledger = await (db.select(db.ledgers)
        ..where((l) => l.id.equals(ledgerId)))
      .getSingleOrNull();

  // 构建 categories 数组（包含图标、层级、父分类信息）
  final categoryItems = <Map<String, dynamic>>[];
  final allCategoriesList = await (db.select(db.categories)
        ..where((c) => c.id.isIn(allCategoriesSet.toList())))
      .get();

  // 先导出一级分类，再导出二级分类（便于导入时先创建父分类）
  allCategoriesList.sort((a, b) {
    if (a.level != b.level) return a.level.compareTo(b.level);
    return a.id.compareTo(b.id);
  });

  for (final cat in allCategoriesList) {
    final categoryItem = <String, dynamic>{
      'name': _sanitizeString(cat.name),
      'kind': cat.kind,
      'level': cat.level,
      'sortOrder': cat.sortOrder, // 保存排序顺序
      'iconType': cat.iconType, // 图标类型: material / custom / community
    };

    // 添加图标信息（如果存在）
    if (cat.icon != null && cat.icon!.isNotEmpty) {
      categoryItem['icon'] = cat.icon;
    }

    // 添加自定义图标路径（如果存在）
    if (cat.customIconPath != null && cat.customIconPath!.isNotEmpty) {
      categoryItem['customIconPath'] = cat.customIconPath;
    }

    // 添加社区图标ID（如果存在）
    if (cat.communityIconId != null && cat.communityIconId!.isNotEmpty) {
      categoryItem['communityIconId'] = cat.communityIconId;
    }

    // 添加父分类名称（如果是二级分类）
    if (cat.level == 2 && cat.parentId != null) {
      final parentCat = allCategoriesList.firstWhere(
        (c) => c.id == cat.parentId,
        orElse: () => allCategoriesList.first, // 不应该发生
      );
      categoryItem['parentName'] = _sanitizeString(parentCat.name);
    }

    categoryItems.add(categoryItem);
  }

  // 构建标签列表
  final tagItems = allUsedTags.values.map((tag) {
    final tagItem = <String, dynamic>{
      'name': _sanitizeString(tag.name),
    };
    if (tag.color != null && tag.color!.isNotEmpty) {
      tagItem['color'] = tag.color;
    }
    return tagItem;
  }).toList();

  // 检查账本是否存在
  if (ledger == null) {
    logger.error('TransactionsJson', '账本 $ledgerId 不存在！');
    throw Exception('账本 $ledgerId 不存在');
  }

  final payload = {
    'version': 6, // 版本升级,新增 syncId 用于跨设备同步
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'ledgerId': ledgerId,
    'ledgerName': ledger.name,
    'currency': ledger.currency,
    'monthStartDay': ledger.monthStartDay,
    'count': items.length,
    'accounts': accountItems,
    'categories': categoryItems,
    'tags': tagItems, // 新增：标签信息
    'items': items,
  };

  logger.debug('TransactionsJson', '导出完成: ${items.length} 条交易, ${categoryItems.length} 个分类');
  return jsonEncode(payload);
}

// --- 导入 ---

/// 将 JSON 数据转换为统一的 ImportData 格式
ImportData parseJsonToImportData(String jsonStr) {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;

  // 解析账户
  final accounts = <ImportAccount>[];
  final jsonAccounts = data['accounts'] as List?;
  if (jsonAccounts != null) {
    for (final acc in jsonAccounts.cast<Map<String, dynamic>>()) {
      accounts.add(ImportAccount(
        name: acc['name'] as String,
        type: acc['type'] as String?,
        currency: acc['currency'] as String?,
        initialBalance: (acc['initialBalance'] as num?)?.toDouble(),
      ));
    }
  }

  // 解析分类
  final categories = <ImportCategory>[];
  final jsonCategories = data['categories'] as List?;
  if (jsonCategories != null) {
    for (final cat in jsonCategories.cast<Map<String, dynamic>>()) {
      categories.add(ImportCategory(
        name: cat['name'] as String,
        kind: cat['kind'] as String,
        level: cat['level'] as int? ?? 1,
        sortOrder: cat['sortOrder'] as int? ?? 0,
        icon: cat['icon'] as String?,
        parentName: cat['parentName'] as String?,
        iconType: cat['iconType'] as String?,
        customIconPath: cat['customIconPath'] as String?,
        communityIconId: cat['communityIconId'] as String?,
      ));
    }
  }

  // 解析标签
  final tags = <ImportTag>[];
  final jsonTags = data['tags'] as List?;
  if (jsonTags != null) {
    for (final tag in jsonTags.cast<Map<String, dynamic>>()) {
      tags.add(ImportTag(
        name: tag['name'] as String,
        color: tag['color']?.toString(),
      ));
    }
  }

  // 解析交易
  final transactions = <ImportTransaction>[];
  final jsonItems = data['items'] as List?;
  if (jsonItems != null) {
    for (final it in jsonItems.cast<Map<String, dynamic>>()) {
      // 解析标签名称列表
      List<String>? tagNames;
      final tagsStr = it['tags'] as String?;
      if (tagsStr != null && tagsStr.trim().isNotEmpty) {
        tagNames = tagsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      // 解析附件元数据
      List<ImportAttachment>? attachments;
      final jsonAttachments = it['attachments'] as List?;
      if (jsonAttachments != null && jsonAttachments.isNotEmpty) {
        attachments = jsonAttachments.cast<Map<String, dynamic>>().map((a) {
          return ImportAttachment(
            fileName: a['fileName'] as String,
            originalName: a['originalName'] as String?,
            fileSize: a['fileSize'] as int?,
            width: a['width'] as int?,
            height: a['height'] as int?,
            sortOrder: a['sortOrder'] as int? ?? 0,
            cloudFileId: a['cloudFileId'] as String?,
            cloudSha256: a['cloudSha256'] as String?,
          );
        }).toList();
      }

      final type = it['type'] as String;
      transactions.add(ImportTransaction(
        type: type,
        amount: (it['amount'] as num).toDouble(),
        categoryName: it['categoryName'] as String?,
        categoryKind: it['categoryKind'] as String?,
        happenedAt: DateTime.parse(it['happenedAt'] as String).toLocal(),
        note: it['note'] as String?,
        // 账户信息：转账用 fromAccountName/toAccountName，其他用 accountName
        accountName: type != 'transfer' ? it['accountName'] as String? : null,
        fromAccountName: type == 'transfer' ? it['fromAccountName'] as String? : null,
        toAccountName: type == 'transfer' ? it['toAccountName'] as String? : null,
        tagNames: tagNames,
        attachments: attachments,
        syncId: it['syncId'] as String?,
      ));
    }
  }

  // monthStartDay 在导出 payload 里有,但这里刻意不读 —— 恢复路径由
  // syncLedgersFromServer 收敛(见 .docs/period-start-date/design.md §4)。
  return ImportData(
    accounts: accounts,
    categories: categories,
    tags: tags,
    transactions: transactions,
    ledgerName: data['ledgerName'] as String?,
    currency: data['currency'] as String?,
  );
}

/// 解析 JSON 并增量导入
///
/// [repo] - 数据仓库
/// [ledgerId] - 目标账本ID
/// [jsonStr] - JSON 字符串
/// [onProgress] - 进度回调 (已处理数, 总数)
///
/// 返回 (inserted,) 元组：
/// - inserted: 新增条数
Future<({int inserted})> importTransactionsJson(
  BaseRepository repo,
  int ledgerId,
  String jsonStr, {
  void Function(int done, int total)? onProgress,
  bool recordChanges = true,
}) async {
  // 1. 解析 JSON 为统一格式
  final importData = parseJsonToImportData(jsonStr);

  // 2. 使用统一导入服务
  // [recordChanges] 默认 true 兼容 CSV 导入路径(`data_import_service` 会
  // 通过 LocalRepository 写 local_changes 让本地变更能推到云端)。
  // SyncEngine.runFullPull 走"从云端拉数据"路径,显式传 false 避免反向回流。
  final result = await dataImportService.importData(
    repo,
    ledgerId,
    importData,
    defaultCurrency: importData.currency ?? 'CNY',
    onProgress: onProgress,
    recordChanges: recordChanges,
  );

  return (inserted: result.inserted,);
}
