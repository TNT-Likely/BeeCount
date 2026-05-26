import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

import '../../ai/core/bill_info.dart';
import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/category_node.dart';
import '../../l10n/app_localizations.dart';
import '../data/tag_seed_service.dart';
import '../system/logger_service.dart';
import 'category_matcher.dart';

/// 账单交易创建服务。
///
/// 把 [BillInfo](AI 提取 + sanitize 后的统一表达)落库成 `transactions` 表
/// 记录,同时挂上分类/账户/标签。被以下渠道复用:
/// - [AiBookkeeper] 的 5 条路径(对话/图片/语音/自动截图/自动文本)
/// - 后续可能接入的手动录入(目前手动走 `repository.addTransaction` 直接落库)
class BillCreationService {
  static const _tag = 'BillCreation';

  final BaseRepository repo;

  BillCreationService(this.repo);

  /// 从 [BillInfo] 创建账单交易。入参的 [bill] 经过 sanitize,
  /// **保证 amount 非空且 abs > 0、time 非空**,内部无需再做兜底。
  ///
  /// 返回创建的交易 ID,失败(数据库异常)返回 null。
  Future<int?> createFromBill({
    required BillInfo bill,
    required int ledgerId,
    List<String>? billingTypes,
    List<String>? customTagNames,
    AppLocalizations? l10n,
    bool autoAddTags = true,
  }) async {
    final amount = bill.amount;
    if (amount == null || amount.abs() <= 0) {
      logger.warning(_tag, '[校验] amount 无效,跳过: ${bill.toJson()}');
      return null;
    }

    // 1. 确定交易类型
    final transactionType = _resolveType(bill);
    logger.debug(_tag,
        '[类型判断] type=${bill.type?.name} amount=$amount → $transactionType');

    // 2. 查询对应类型的所有可用分类
    final categories = await _loadUsableCategories(transactionType);

    // 3. 匹配分类(AI 名称 → 完全匹配 → 模糊匹配 → 规则匹配 → 兜底"其他")
    var categoryId =
        await _matchCategory(bill.category, bill.note ?? '', categories);
    if (categoryId == null && categories.isNotEmpty) {
      categoryId = _fallbackCategoryId(categories);
    }

    // 4. 匹配账户
    int? accountId;
    int? toAccountId;
    if (transactionType == 'transfer') {
      final source = bill.fromAccount ?? bill.account;
      if (source != null && source.trim().isNotEmpty) {
        accountId = await _matchAccountByName(source, ledgerId);
      }
      if (bill.toAccount != null && bill.toAccount!.trim().isNotEmpty) {
        toAccountId = await _matchAccountByName(bill.toAccount!, ledgerId);
      }
      if (accountId != null && accountId == toAccountId) {
        toAccountId = null;
      }
    } else {
      accountId = await _matchAccount(
        bill.account,
        ledgerId,
        transactionType: transactionType,
      );
    }

    // 5. 落库
    final happenedAt = bill.time ?? DateTime.now();
    final transactionId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: transactionType,
      amount: amount.abs(),
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      happenedAt: happenedAt,
      note: bill.note,
    );

    // 6. 自动标签
    if (autoAddTags) {
      await _addTags(
        transactionId,
        billingTypes: billingTypes,
        customTagNames: customTagNames ?? bill.tags,
        l10n: l10n,
      );
    }

    // 7. 汇总日志
    String? categoryName;
    String? accountName;
    if (categoryId != null) {
      categoryName = categories.firstWhereOrNull((c) => c.id == categoryId)?.name;
    }
    if (accountId != null) {
      accountName = (await repo.getAccount(accountId))?.name;
    }
    final typeStr = transactionType == 'income'
        ? '收入'
        : (transactionType == 'transfer' ? '转账' : '支出');
    final tagSources = <String>[
      ...?billingTypes,
      ...?(customTagNames ?? bill.tags),
    ];
    logger.info(
      _tag,
      '[自动记账] 成功 | ID:$transactionId | ${amount.abs()}元 | $typeStr | '
      '分类:${categoryName ?? '未设置'} | 账户:${accountName ?? '未设置'} | '
      '时间:${_formatDateTime(happenedAt)} | 备注:${bill.note ?? '无'} | '
      '标签:${tagSources.isNotEmpty ? tagSources.join(',') : '无'}',
    );

    return transactionId;
  }

  /// 获取按类型过滤的可用分类(排除有子分类的父分类)。公开给业务复用。
  Future<List<Category>> getCategoriesByType(String type) async {
    final top = await repo.getTopLevelCategories(type);
    final all = <Category>[...top];
    for (final c in top) {
      all.addAll(await repo.getSubCategories(c.id));
    }
    return all;
  }

  // ============================================================
  // 内部实现
  // ============================================================

  /// 决定 transaction.type:
  /// 1. BillInfo.type 显式 → 直接用
  /// 2. category 是「转账」字样 → transfer
  /// 3. 默认 expense(AI 模式下 amount 负值代表支出,prompt 已要求 AI 自行标
  ///    type;若 type 漏了我们保守按 expense 处理,避免误记成收入)
  String _resolveType(BillInfo bill) {
    if (bill.type == BillType.transfer) return 'transfer';
    if (bill.type == BillType.expense) return 'expense';
    if (bill.type == BillType.income) return 'income';
    final cat = bill.category?.trim();
    if (cat == '转账' || cat == '轉帳' || cat?.toLowerCase() == 'transfer') {
      return 'transfer';
    }
    return 'expense';
  }

  Future<List<Category>> _loadUsableCategories(String type) async {
    final top = await repo.getTopLevelCategories(type);
    final all = <Category>[...top];
    for (final c in top) {
      all.addAll(await repo.getSubCategories(c.id));
    }
    return CategoryHierarchy.getUsableCategories(all);
  }

  /// 按 AI 给的 category 名称匹配本地分类。完全匹配 → 模糊匹配 → 规则匹配。
  Future<int?> _matchCategory(
    String? aiCategoryName,
    String note,
    List<Category> categories,
  ) async {
    if (categories.isEmpty) return null;

    if (aiCategoryName != null && aiCategoryName.isNotEmpty) {
      // 完全匹配
      final exact =
          categories.firstWhereOrNull((c) => c.name == aiCategoryName);
      if (exact != null) {
        logger.debug(_tag,
            '[分类匹配-完全] AI 分类"$aiCategoryName" → ${exact.name}(ID:${exact.id})');
        return exact.id;
      }

      // 模糊匹配:分类名包含 AI 名,或 AI 名包含分类名(取匹配长度最长的)
      Category? best;
      var bestScore = 0;
      for (final c in categories) {
        var score = 0;
        if (c.name.contains(aiCategoryName)) {
          score = aiCategoryName.length;
        } else if (aiCategoryName.contains(c.name)) {
          score = c.name.length;
        }
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      if (best != null) {
        logger.debug(_tag,
            '[分类匹配-模糊] AI 分类"$aiCategoryName" → ${best.name}(ID:${best.id})');
        return best.id;
      }
      logger.debug(_tag, '[分类匹配] AI 分类"$aiCategoryName" 未匹配,降级规则匹配');
    }

    return CategoryMatcher.smartMatch(
      merchant: note,
      fullText: note,
      categories: categories,
    );
  }

  /// 获取兜底分类("其他"系列或最后一个)
  int? _fallbackCategoryId(List<Category> categories) {
    if (categories.isEmpty) return null;
    const keywords = ['其他', 'other', '其它', '杂项', 'misc'];
    for (final k in keywords) {
      final hit = categories.firstWhereOrNull(
        (c) => c.name.toLowerCase().contains(k.toLowerCase()),
      );
      if (hit != null) {
        logger.debug(_tag, '[分类兜底] 使用"${hit.name}"(ID:${hit.id})');
        return hit.id;
      }
    }
    final last = categories.last;
    logger.debug(_tag, '[分类兜底] 使用"${last.name}"(ID:${last.id})');
    return last.id;
  }

  /// 收入/支出场景的账户匹配。
  Future<int?> _matchAccount(
    String? aiAccountName,
    int ledgerId, {
    required String transactionType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('account_feature_enabled') ?? true;
    if (!enabled) {
      logger.debug(_tag, '[账户匹配] 账户功能未启用,跳过');
      return null;
    }

    if (aiAccountName == null || aiAccountName.isEmpty) {
      logger.debug(_tag, '[账户匹配] AI 未识别账户,使用默认账户');
      return _getDefaultAccountId(transactionType, ledgerId, prefs);
    }

    final matched = await _matchAccountByName(aiAccountName, ledgerId);
    if (matched != null) return matched;

    logger.debug(_tag, '[账户匹配] "$aiAccountName" 未匹配,尝试默认账户');
    return _getDefaultAccountId(transactionType, ledgerId, prefs);
  }

  /// 按名称匹配账户(限同币种)。完全 → 模糊 → 类型映射。
  Future<int?> _matchAccountByName(String accountName, int ledgerId) async {
    final ledger = await repo.getLedgerById(ledgerId);
    if (ledger == null) return null;

    final allAccounts = await repo.getAllAccounts();
    final pool =
        allAccounts.where((a) => a.currency == ledger.currency).toList();
    final target = accountName.toLowerCase().trim();

    // 完全匹配
    for (final a in pool) {
      if (a.name.toLowerCase().trim() == target) {
        logger.debug(_tag,
            '[账户匹配-完全] "$accountName" → ${a.name}(ID:${a.id})');
        return a.id;
      }
    }
    // 模糊匹配
    for (final a in pool) {
      final n = a.name.toLowerCase().trim();
      if (n.contains(target) || target.contains(n)) {
        logger.debug(_tag,
            '[账户匹配-模糊] "$accountName" → ${a.name}(ID:${a.id})');
        return a.id;
      }
    }
    // 类型映射(余额宝 → 支付宝 等)
    const typeMap = {
      '余额宝': ['支付宝', 'alipay'],
      '花呗': ['支付宝', 'alipay'],
      '微信支付': ['微信', 'wechat'],
      '微信钱包': ['微信', 'wechat'],
      '零钱': ['微信', 'wechat'],
      '零钱通': ['微信', 'wechat'],
    };
    final related = typeMap[target] ?? const [];
    for (final a in pool) {
      final n = a.name.toLowerCase().trim();
      for (final r in related) {
        if (n.contains(r.toLowerCase())) {
          logger.debug(_tag,
              '[账户匹配-类型] "$accountName" → ${a.name}(ID:${a.id})');
          return a.id;
        }
      }
    }
    return null;
  }

  Future<int?> _getDefaultAccountId(
    String transactionType,
    int ledgerId,
    SharedPreferences prefs,
  ) async {
    if (transactionType == 'transfer') return null;
    final key = transactionType == 'income'
        ? 'default_income_account_id'
        : 'default_expense_account_id';
    final defaultId = prefs.getInt(key);
    if (defaultId == null) return null;

    final ledger = await repo.getLedgerById(ledgerId);
    if (ledger == null) return null;
    final account = await repo.getAccount(defaultId);
    if (account == null) return null;
    if (account.currency != ledger.currency) {
      logger.debug(_tag,
          '[默认账户] 币种不匹配: ${account.currency} vs ${ledger.currency}');
      return null;
    }
    logger.debug(_tag, '[默认账户] → ${account.name}(ID:${account.id})');
    return defaultId;
  }

  /// 自动添加标签(记账方式 + 自定义)
  Future<void> _addTags(
    int transactionId, {
    List<String>? billingTypes,
    List<String>? customTagNames,
    AppLocalizations? l10n,
  }) async {
    try {
      final names = <String>{};
      if (billingTypes != null && billingTypes.isNotEmpty && l10n != null) {
        names.addAll(TagSeedService.getBillingTagNames(billingTypes, l10n));
      }
      if (customTagNames != null && customTagNames.isNotEmpty) {
        names.addAll(customTagNames
            .map((n) => n.trim())
            .where((n) => n.isNotEmpty));
      }
      if (names.isEmpty) return;

      final tagIds = <int>[];
      for (final name in names) {
        var tag = await repo.getTagByName(name);
        if (tag == null) {
          final color = TagSeedService.getRandomColor();
          final id = await repo.createTag(name: name, color: color);
          tagIds.add(id);
        } else {
          tagIds.add(tag.id);
        }
      }
      if (tagIds.isNotEmpty) {
        await repo.addTagsToTransaction(
            transactionId: transactionId, tagIds: tagIds);
      }
    } catch (e, st) {
      logger.error(_tag, '[标签] 添加失败', e, st);
    }
  }

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}';
  }
}
