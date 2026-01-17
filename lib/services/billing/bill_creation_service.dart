import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/category_node.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';
import '../data/tag_seed_service.dart';
import 'category_matcher.dart';
import 'ocr_service.dart';

/// 账单创建服务
///
/// 提供统一的账单创建接口，供OCR手动扫描和自动记账使用
class BillCreationService {
  final BaseRepository repo;
  static const _tag = 'BillCreation';

  BillCreationService(this.repo);

  /// 匹配分类
  ///
  /// 优先使用AI识别的分类名称，失败则降级到规则匹配
  /// 匹配优先级：完全匹配 > 模糊匹配（包含） > 规则匹配
  /// 返回匹配的分类ID，如果都失败则返回null
  Future<int?> matchCategory(
    OcrResult result,
    List<Category> categories,
  ) async {
    // 1. 优先使用AI识别的分类
    if (result.aiCategoryName != null &&
        result.aiCategoryName!.isNotEmpty &&
        categories.isNotEmpty) {
      final aiCategory = result.aiCategoryName!;

      // 1.1 尝试完全匹配
      try {
        final matchedCategory = categories.firstWhere(
          (cat) => cat.name == aiCategory,
        );
        final transactionType = result.aiType ?? 'expense';
        logger.debug(_tag, '[分类匹配-完全] AI分类"$aiCategory"($transactionType) → ${matchedCategory.name}(ID:${matchedCategory.id})');
        return matchedCategory.id;
      } catch (_) {
        // 完全匹配失败，继续尝试模糊匹配
      }

      // 1.2 尝试模糊匹配（AI分类名包含在分类名中，或分类名包含在AI分类名中）
      Category? fuzzyMatch;
      int bestScore = 0;

      for (final cat in categories) {
        int score = 0;

        // 情况1: 分类名包含AI分类名（如：餐饮美食 包含 餐饮）
        if (cat.name.contains(aiCategory)) {
          score = aiCategory.length; // 匹配长度越长，分数越高
        }
        // 情况2: AI分类名包含分类名（如：早餐 包含在 午餐早餐 中，但这种情况较少见）
        else if (aiCategory.contains(cat.name)) {
          score = cat.name.length;
        }

        if (score > bestScore) {
          bestScore = score;
          fuzzyMatch = cat;
        }
      }

      if (fuzzyMatch != null) {
        final transactionType = result.aiType ?? 'expense';
        logger.debug(_tag, '[分类匹配-模糊] AI分类"$aiCategory"($transactionType) → ${fuzzyMatch.name}(ID:${fuzzyMatch.id})');
        return fuzzyMatch.id;
      }

      logger.debug(_tag, '[分类匹配] AI分类"$aiCategory"未找到匹配，降级使用规则匹配');
    }

    // 2. 降级使用规则匹配
    if (categories.isNotEmpty) {
      return CategoryMatcher.smartMatch(
        merchant: result.note,
        fullText: result.rawText,
        categories: categories,
      );
    }

    return null;
  }

  /// 匹配账户
  ///
  /// 在账户功能启用的前提下，根据AI识别的账户名称匹配账户ID
  /// 只匹配与当前账本币种相同的账户
  /// [transactionType] 交易类型：'income' 或 'expense'，用于在未匹配时使用默认账户
  Future<int?> matchAccount(
    OcrResult result,
    int ledgerId, {
    String transactionType = 'expense',
    String? accountName,
  }) async {
    // 只要外部传了 accountName，我们就直接去匹配，不再往下走 AI 识别
    if (accountName != null && accountName.isNotEmpty) {
      final repository = repo;
      final allAccounts = await repository.getAllAccounts();
      try {
        // 在所有账户中寻找匹配项（包含关系匹配）
        final forcedAccount = allAccounts.firstWhere(
          (a) => a.name.contains(accountName) || accountName.contains(a.name),
        );
        logger.debug(_tag, '[精准匹配] 🎯 强制锁定账户: ${forcedAccount.name}(ID:${forcedAccount.id})');
        
        // 关键点：直接返回 ID，后面所有的逻辑（AI识别、默认账户等）都会被跳过
        return forcedAccount.id; 
      } catch (e) {
        logger.warning(_tag, '[精准匹配] ❌ 资产库中找不到名为 "$accountName" 的账户');
        // 如果没找到，代码会继续往下走原本的 AI 识别流程
      }
    }


    // 1. 检查账户功能是否启用
    final prefs = await SharedPreferences.getInstance();
    final accountFeatureEnabled = prefs.getBool('account_feature_enabled') ?? true;

    if (!accountFeatureEnabled) {
      logger.debug(_tag, '[账户匹配] 账户功能未启用，跳过匹配');
      return null;
    }

    // 2. 检查是否有AI识别的账户名称，如果没有则尝试使用默认账户
    if (result.aiAccountName == null || result.aiAccountName!.isEmpty) {
      logger.debug(_tag, '[账户匹配] AI未识别账户，尝试使用默认账户');
      return await _getDefaultAccountId(transactionType, ledgerId, prefs);
    }

    // 3. 获取账本信息以确定币种
    final repository = repo;
    final ledger = await repository.getLedgerById(ledgerId);

    if (ledger == null) {
      logger.debug(_tag, '[账户匹配] 账本不存在，跳过匹配');
      return null;
    }

    // 4. 查询与账本币种相同的所有账户
    final allAccounts = await repository.getAllAccounts();
    final matchingAccounts = allAccounts
        .where((a) => a.currency == ledger.currency)
        .toList();

    // 5. 根据账户名称匹配（多级优先级匹配）
    final aiAccountName = result.aiAccountName!.toLowerCase().trim();

    // 第一优先级：名称完全相等（忽略大小写和空格）
    for (final account in matchingAccounts) {
      final accountNameLower = account.name.toLowerCase().trim();
      if (accountNameLower == aiAccountName) {
        logger.debug(_tag, '[账户匹配-完全] "${result.aiAccountName}" → ${account.name}(ID:${account.id})');
        return account.id;
      }
    }

    // 第二优先级：名称包含关系（模糊匹配）
    for (final account in matchingAccounts) {
      final accountNameLower = account.name.toLowerCase().trim();
      if (accountNameLower.contains(aiAccountName) ||
          aiAccountName.contains(accountNameLower)) {
        logger.debug(_tag, '[账户匹配-模糊] "${result.aiAccountName}" → ${account.name}(ID:${account.id})');
        return account.id;
      }
    }

    // 第三优先级：账户类型匹配
    final accountTypeMap = {
      '余额宝': ['支付宝', 'alipay'],
      '花呗': ['支付宝', 'alipay'],
      '微信支付': ['微信', 'wechat'],
      '微信钱包': ['微信', 'wechat'],
      '零钱': ['微信', 'wechat'],
      '零钱通': ['微信', 'wechat'],
    };

    final relatedTypes = accountTypeMap[aiAccountName] ?? [];
    if (relatedTypes.isNotEmpty) {
      for (final account in matchingAccounts) {
        final accountNameLower = account.name.toLowerCase().trim();
        for (final type in relatedTypes) {
          if (accountNameLower.contains(type.toLowerCase())) {
            logger.debug(_tag, '[账户匹配-类型] "${result.aiAccountName}" → ${account.name}(ID:${account.id})');
            return account.id;
          }
        }
      }
    }

    logger.debug(_tag, '[账户匹配] "${result.aiAccountName}"未匹配，尝试默认账户');
    return await _getDefaultAccountId(transactionType, ledgerId, prefs);
  }

  /// 获取默认账户ID（验证币种匹配）
  Future<int?> _getDefaultAccountId(String transactionType, int ledgerId, SharedPreferences prefs) async {
    try {
      // 1. 根据类型获取默认账户ID
      final defaultAccountId = transactionType == 'income'
          ? prefs.getInt('default_income_account_id')
          : prefs.getInt('default_expense_account_id');

      if (defaultAccountId == null) {
        logger.debug(_tag, '[默认账户] 未设置默认${transactionType == 'income' ? '收入' : '支出'}账户');
        return null;
      }

      // 2. 获取账本币种
      final repository = repo;
      final ledger = await repository.getLedgerById(ledgerId);
      if (ledger == null) return null;

      // 3. 获取默认账户信息
      final account = await repository.getAccount(defaultAccountId);
      if (account == null) {
        logger.debug(_tag, '[默认账户] 账户不存在');
        return null;
      }

      // 4. 验证币种匹配
      if (account.currency != ledger.currency) {
        logger.debug(_tag, '[默认账户] 币种不匹配: ${account.currency} vs ${ledger.currency}');
        return null;
      }

      logger.debug(_tag, '[默认账户] 使用${transactionType == 'income' ? '收入' : '支出'}账户 → ${account.name}(ID:${account.id})');
      return defaultAccountId;
    } catch (e) {
      logger.error(_tag, '[默认账户] 获取失败', e);
      return null;
    }
  }

  /// 创建账单交易
  ///
  /// [result] OCR识别结果（包含AI增强）
  /// [ledgerId] 账本ID
  /// [note] 备注（可选）
  /// [billingTypes] 记账方式列表，如 ['image', 'ai'] 表示开启AI的图片记账
  /// [l10n] 国际化对象，用于获取标签名称
  /// [autoAddTags] 是否自动关联标签，默认true
  /// 返回创建的交易ID，如果创建失败则返回null
  Future<int?> createBillTransaction({
    required OcrResult result,
    required int ledgerId,
    String? note,
    List<String>? billingTypes,
    AppLocalizations? l10n,
    bool autoAddTags = true,
    String? type, // 🟢 增加这一行，让它能接收“收入/支出”指令
    String? accountName,
  }) async {
    // 1. 验证金额
    if (result.amount == null || result.amount!.abs() <= 0) {
      return null;
    }

// 🌟 第一步：先定义 repository (把原本在后面的定义挪到这里)
    final repository = repo; 

    // 🌟 第二步：获取账户列表
    final allAccounts = await repository.getAllAccounts();

    // 2. 确定交易类型
    // 🔥 新的优先级：强制指定类型 > AI识别类型 > 关键字识别 ...
    String transactionType;
    String typeSource = '';

    // 🌟 第一步：首先检查外部是否传了“强制指令” (就是我们从管道传进来的那个 type)
    if (type != null && type.isNotEmpty) {
      transactionType = type; // 如果传了 'income'，直接用！
      typeSource = '强制指定';
    }

    else if (result.aiType != null && result.aiType!.isNotEmpty) {
      transactionType = result.aiType!;
      typeSource = 'AI识别';
    } else {
      // 尝试从OCR文本中识别关键字和符号
      final rawTextLower = result.rawText.toLowerCase();
      final rawText = result.rawText;

      // 检查是否有加号（明确的收入标志）
      final hasPlusSign = RegExp(r'\+\s*\d+\.?\d*').hasMatch(rawText);

      // 明确的收入关键字（优先级最高）
      final strongIncomeKeywords = ['转入成功', '转入', '收款', '收入', '到账', '退款', '入账', '收益'];
      // 明确的支出关键字
      final strongExpenseKeywords = ['付款', '支付', '支出', '消费', '转出'];

      // 检查明确的收入关键字
      bool hasStrongIncomeKeyword = strongIncomeKeywords.any((k) => rawTextLower.contains(k));
      // 检查明确的支出关键字
      bool hasStrongExpenseKeyword = strongExpenseKeywords.any((k) => rawTextLower.contains(k));

      if (hasPlusSign) {
        // 有加号，明确表示收入
        transactionType = 'income';
        typeSource = '加号(收入)';
      } else if (hasStrongIncomeKeyword && !hasStrongExpenseKeyword) {
        // 明确的收入关键字
        transactionType = 'income';
        typeSource = '关键字(收入)';
      } else if (hasStrongExpenseKeyword && !hasStrongIncomeKeyword) {
        // 明确的支出关键字
        transactionType = 'expense';
        typeSource = '关键字(支出)';
      } else if (hasStrongIncomeKeyword && hasStrongExpenseKeyword) {
        // 同时出现收入和支出关键字，优先判断收入（因为收入关键字通常更明确）
        transactionType = 'income';
        typeSource = '关键字冲突(收入优先)';
      } else if (result.amount! < 0) {
        // 负数金额 → 支出
        transactionType = 'expense';
        typeSource = '负号(支出)';
      } else if (result.amount! > 0) {
        // 正数金额且无关键字，默认为支出（更安全的假设）
        transactionType = 'expense';
        typeSource = '默认(支出)';
      } else {
        // 金额为0或null，默认支出
        transactionType = 'expense';
        typeSource = '默认(支出)';
      }
    }

    logger.debug(_tag, '[类型判断] $typeSource → ${transactionType == 'income' ? '收入' : '支出'}');



    // 3. 查询对应类型的所有分类
    final topLevelCategories = await repository.getTopLevelCategories(transactionType);
    final allCategories = <Category>[];
    allCategories.addAll(topLevelCategories);
    // 获取所有子分类
    for (final category in topLevelCategories) {
      final subCategories = await repository.getSubCategories(category.id);
      allCategories.addAll(subCategories);
    }

    // 3.1 过滤出可用于记账的分类（排除有子分类的父分类）
    final categories = CategoryHierarchy.getUsableCategories(allCategories);

    // 4. 匹配分类
    int? categoryId = await matchCategory(result, categories);

    // 4.1 如果没有匹配到分类，尝试使用"其他"分类作为兜底
    if (categoryId == null && categories.isNotEmpty) {
      categoryId = await _getFallbackCategoryId(categories, transactionType);
    }

   // 5. 匹配账户（调整后的极简版）
    int? accountId; // 👈 1. 先不给值
    final String? searchContent = note ?? result.note;

    // 🌟 优先通过备注关键词匹配（你的逻辑）
    if (searchContent != null) {
      final sortedAccounts = allAccounts.toList()
        ..sort((a, b) => b.name.length.compareTo(a.name.length)); // 解决 Cash 截胡问题
      
      for (var account in sortedAccounts) {
        if (searchContent.toLowerCase().contains(account.name.toLowerCase())) {
          accountId = account.id;
          logger.debug(_tag, '🎯 [步骤5] 备注精准匹配账户: ${account.name}');
          break;
        }
      }
    }

    // 🌟 如果备注没匹配到，再走原生逻辑（AI识别 + 默认账户）
    if (accountId == null) {
      accountId = await matchAccount(
        result, 
        ledgerId, 
        transactionType: transactionType,
        accountName: accountName, // 👈 核心修改：把接力棒传给 matchAccount
      );
    }

    // 如果最后还是 null，由底层逻辑或默认账户处理
    // 这样保证了 accountId 在进入第 7 步（日志）前是有值的

    // 6. 确定交易时间（优先使用识别的时间，否则使用当前时间）
    final DateTime happenedAt = result.time ?? DateTime.now();


    // 7. 获取分类和账户名称（用于日志）
    String? categoryName;
    if (categoryId != null) {
      final category = categories.where((c) => c.id == categoryId).firstOrNull;
      categoryName = category?.name;
    }
    if (accountId != null) {
      final account = await repository.getAccount(accountId);
      accountName = account?.name;
    }

    // 8. 确定最终备注并进行修剪
    String? finalNote = result.note ?? note;
    
    if (finalNote != null) {
      // 🌟 1. 剔除常见的支付前缀（如“微信支付：”、“支付宝支付：”）
      // 使用正则匹配，支持中文冒号和英文冒号
      finalNote = finalNote.replaceAll(RegExp(r'^(微信支付|支付宝支付|支付|收款)[：:]\s*'), '');

      // 🌟 2. 进一步优化：如果备注里还包含账户名，也把它剔除（可选）
      // 比如将 "支付宝转账收款" 简化为 "转账收款"
      if (accountId != null) {
        final currentAccount = allAccounts.firstWhereOrNull((a) => a.id == accountId);
        if (currentAccount != null) {
          // 只剔除开头的账户名，避免误删中间的有效信息
          finalNote = finalNote.replaceFirst(currentAccount.name, '').trim();
        }
      }

      // 🌟 3. 清理掉可能残余的起始符号
      if (finalNote.startsWith('：') || finalNote.startsWith(':')) {
        finalNote = finalNote.substring(1).trim();
      }
    }

    // 9. 使用Repository创建交易
    final finalAmount = result.amount!.abs();
    final transactionId = await repository.addTransaction(
      ledgerId: ledgerId,
      type: transactionType,
      amount: finalAmount,
      categoryId: categoryId,
      accountId: accountId,
      happenedAt: happenedAt,
      note: finalNote,
    );

    // 10. 自动添加记账方式标签（根据设置开关）
    if (autoAddTags && billingTypes != null && billingTypes.isNotEmpty && l10n != null) {
      await _addBillingTypeTags(transactionId, billingTypes, l10n);
    }

    // 11. 打印最终交易信息汇总（一行）
    final typeStr = transactionType == 'income' ? '收入' : '支出';
    final timeStr = _formatDateTime(happenedAt);
    final categoryStr = categoryName ?? '未设置';
    final accountStr = accountName ?? '未设置';
    final noteStr = finalNote ?? '无';
    final tagsStr = billingTypes?.join(',') ?? '无';

    logger.info(_tag, '[自动记账] 成功 | ID:$transactionId | $finalAmount元 | $typeStr | 分类:$categoryStr | 账户:$accountStr | 时间:$timeStr | 备注:$noteStr | 标签:$tagsStr');

    return transactionId;
  }

  /// 为交易添加记账方式标签
  Future<void> _addBillingTypeTags(int transactionId, List<String> billingTypes, AppLocalizations l10n) async {
    try {
      final tagNames = TagSeedService.getBillingTagNames(billingTypes, l10n);
      if (tagNames.isEmpty) return;

      final tagIds = <int>[];
      for (final tagName in tagNames) {
        // 查找标签，如果不存在则创建
        var tag = await repo.getTagByName(tagName);
        if (tag == null) {
          // 标签不存在，创建它
          final color = TagSeedService.getRandomColor();
          final tagId = await repo.createTag(name: tagName, color: color);
          tagIds.add(tagId);
          logger.debug(_tag, '[标签] 创建新标签: $tagName (ID:$tagId)');
        } else {
          tagIds.add(tag.id);
          logger.debug(_tag, '[标签] 使用已有标签: $tagName (ID:${tag.id})');
        }
      }

      // 关联标签到交易
      if (tagIds.isNotEmpty) {
        await repo.addTagsToTransaction(transactionId: transactionId, tagIds: tagIds);
        logger.info(_tag, '[标签] 已为交易 $transactionId 添加 ${tagIds.length} 个标签');
      }
    } catch (e, stackTrace) {
      logger.error(_tag, '[标签] 添加标签失败', e, stackTrace);
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// 获取兜底分类ID
  /// 优先使用"其他"分类，如果没有则使用第一个分类
  Future<int?> _getFallbackCategoryId(List<Category> categories, String transactionType) async {
    if (categories.isEmpty) return null;

    // 尝试查找"其他"分类（支持多种命名方式）
    final otherKeywords = ['其他', 'other', '其它', '杂项', 'misc'];
    for (final keyword in otherKeywords) {
      final otherCategory = categories.where(
        (c) => c.name.toLowerCase().contains(keyword.toLowerCase())
      ).toList().firstOrNull;
      if (otherCategory != null) {
        logger.debug(_tag, '[分类兜底] 使用"${otherCategory.name}"(ID:${otherCategory.id})');
        return otherCategory.id;
      }
    }

    // 如果没有"其他"分类，使用排序最后的分类
    final lastCategory = categories.last;
    logger.debug(_tag, '[分类兜底] 使用"${lastCategory.name}"(ID:${lastCategory.id})');
    return lastCategory.id;
  }

  /// 获取分类列表（按类型）
  ///
  /// [type] 'income' 或 'expense'
  Future<List<Category>> getCategoriesByType(String type) async {
    final repository = repo;
    final topLevelCategories = await repository.getTopLevelCategories(type);
    final allCategories = <Category>[];
    allCategories.addAll(topLevelCategories);
    // 获取所有子分类
    for (final category in topLevelCategories) {
      final subCategories = await repository.getSubCategories(category.id);
      allCategories.addAll(subCategories);
    }
    return allCategories;
  }
}
