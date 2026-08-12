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
/// 确保某币种 → 账本本位币的汇率在本地可用;返回是否可用。
///
/// 由 provider 层注入(见 `aiBookkeeperProvider` 装配),这样 service 层不必
/// 依赖 Riverpod,后台自动记账也能复用同一条汇率预拉路径(A6)。
typedef EnsureRate = Future<bool> Function(String currencyCode);

class BillCreationService {
  static const _tag = 'BillCreation';

  final BaseRepository repo;

  /// 见 [EnsureRate]。未注入(单测 / 老调用方)时跳过预拉,行为与改动前一致。
  final EnsureRate? ensureRate;

  BillCreationService(this.repo, {this.ensureRate});

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

    // 3.5 账本本位币 + AI 给的币种(.docs/multi-currency-ai A1/A2)
    final ledgerBase = await _ledgerCurrency(ledgerId);
    final requestedCurrency = bill.currency?.trim().toUpperCase();

    // 4. 匹配账户。**账户候选池按这笔的币种筛**(A3,与手动记账
    //    AccountSelector.filterCurrency 同构):AI 给了币种就只在该币种的账户
    //    里找;没给币种则全币种可选,由命中的账户反过来决定币种(L7)。
    int? accountId;
    int? toAccountId;
    if (transactionType == 'transfer') {
      final source = bill.fromAccount ?? bill.account;
      if (source != null && source.trim().isNotEmpty) {
        accountId = await _matchAccountByName(source, requestedCurrency);
      }
      if (bill.toAccount != null && bill.toAccount!.trim().isNotEmpty) {
        // **跨币种转账守卫**(.docs/multi-currency-ledger 01 §4.4):转入账户必须
        // 与转出账户同币种。手动路径(transfer_form)会 toast 报错并重置转入
        // 账户;AI 是无人值守,所以退化成「匹配不到转入账户」—— 这与 AI 本来
        // 就没说转入账户时的落库形态一致,不会造出一笔币种错乱的转账。
        //
        // 注意:池不能只按 requestedCurrency 筛 —— AI 不给币种时那是 null,
        // 池就全币种开放,建行(CNY)→Chase(USD) 会被当成合法转账落库。
        final fromCurrency = accountId == null
            ? requestedCurrency
            : (await repo.getAccount(accountId))?.currency.toUpperCase() ??
                requestedCurrency;
        toAccountId = await _matchAccountByName(
            bill.toAccount!, fromCurrency ?? requestedCurrency);
      }
      if (accountId != null && accountId == toAccountId) {
        toAccountId = null;
      }
    } else {
      accountId = await _matchAccount(
        bill.account,
        ledgerId,
        transactionType: transactionType,
        requestedCurrency: requestedCurrency,
        ledgerBase: ledgerBase,
      );
    }

    // 4.5 定交易币种:命中账户 → 随账户(账户内不混币,L7/L12 的不变量);
    //     否则用 AI 给的;都没有 → 账本本位币。
    final matchedAccount = accountId == null ? null : await repo.getAccount(accountId);
    final accountCurrency = (matchedAccount?.currency.isNotEmpty ?? false)
        ? matchedAccount!.currency.toUpperCase()
        : null;
    final txCurrency = accountCurrency ?? requestedCurrency ?? ledgerBase;
    if (requestedCurrency != null &&
        accountCurrency != null &&
        requestedCurrency != accountCurrency) {
      // 池已按币种筛过,正常走不到这里;留日志防未来改动引入静默错币种
      logger.warning(_tag,
          '[币种] AI 给 $requestedCurrency 但命中账户是 $accountCurrency,以账户为准');
    }
    // 外币且**本地还没有**有效汇率时才拉(A6)。本地已有就直接用 —— 否则
    // 多笔外币账单(一张图 10 笔)会各打一次 force 网络请求,后台自动记账
    // 同样受害;先查本地也让同一批里的后续账单命中第一笔刚落库的汇率。
    if (txCurrency != ledgerBase &&
        !await _hasLocalRate(ledgerBase, txCurrency)) {
      await _ensureRateAvailable(txCurrency);
    }

    // 5. 落库。nativeAmount 不传 —— 交给 LocalRepository._resolveTxCurrency
    //    按有效汇率折算;缺汇率时它会退化成 =amount 并被 L11 检测捞回。
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
      currencyCode: txCurrency,
    );

    // 6. 自动标签:受「智能记账自动关联标签」开关控制(默认开启,关闭后不挂任何标签)。
    //    与账户功能开关一致直接读 prefs;入参 autoAddTags 作为代码级强制开关,二者取「与」。
    if (autoAddTags) {
      final prefs = await SharedPreferences.getInstance();
      final autoTagsEnabled = prefs.getBool('smartBillingAutoTags') ?? true;
      if (autoTagsEnabled) {
        await _addTags(
          transactionId,
          billingTypes: billingTypes,
          customTagNames: customTagNames ?? bill.tags,
          l10n: l10n,
        );
      }
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
    required String? requestedCurrency,
    required String ledgerBase,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('account_feature_enabled') ?? true;
    if (!enabled) {
      logger.debug(_tag, '[账户匹配] 账户功能未启用,跳过');
      return null;
    }

    if (aiAccountName == null || aiAccountName.isEmpty) {
      logger.debug(_tag, '[账户匹配] AI 未识别账户,使用默认账户');
      return _getDefaultAccountId(
          transactionType, prefs, requestedCurrency ?? ledgerBase);
    }

    final matched = await _matchAccountByName(aiAccountName, requestedCurrency);
    if (matched != null) return matched;

    logger.debug(_tag, '[账户匹配] "$aiAccountName" 未匹配,尝试默认账户');
    return _getDefaultAccountId(
        transactionType, prefs, requestedCurrency ?? ledgerBase);
  }

  /// 按名称匹配账户。完全 → 模糊 → 类型映射。
  ///
  /// [currency] 非空时只在该币种的账户里找(AI 明确说了外币,就不该匹配到本位
  /// 币账户 —— 45 美元记成 45 元是比「没匹配到账户」严重得多的错);为空则全
  /// 币种可选,命中的账户反过来决定这笔的币种(L7)。
  Future<int?> _matchAccountByName(String accountName, String? currency) async {
    final allAccounts = await repo.getAllAccounts();
    // 账户隐藏(#240):AI 自动记账不匹配隐藏账户(隐藏 = 不再作为新交易记账
    // 目标,与手动选择器 / Web AI 候选一致);未匹配则回落默认账户。
    final wanted = currency?.toUpperCase();
    final pool = allAccounts
        .where((a) =>
            !a.hidden &&
            (wanted == null || a.currency.toUpperCase() == wanted))
        .toList();
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

  /// 默认账户。[txCurrency] 是这笔的币种(AI 给的,没给就是账本本位币)——
  /// 记外币时本位币的默认账户**不适用**,返回 null 让这笔不挂账户(Q3),
  /// 而不是硬塞一个币种不符的账户进去。
  Future<int?> _getDefaultAccountId(
    String transactionType,
    SharedPreferences prefs,
    String txCurrency,
  ) async {
    if (transactionType == 'transfer') return null;
    final key = transactionType == 'income'
        ? 'default_income_account_id'
        : 'default_expense_account_id';
    final defaultId = prefs.getInt(key);
    if (defaultId == null) return null;

    final account = await repo.getAccount(defaultId);
    if (account == null) return null;
    if (account.currency.toUpperCase() != txCurrency.toUpperCase()) {
      logger.debug(_tag,
          '[默认账户] 币种不匹配: ${account.currency} vs $txCurrency');
      return null;
    }
    logger.debug(_tag, '[默认账户] → ${account.name}(ID:${account.id})');
    return defaultId;
  }

  /// 账本本位币(空/查不到兜底 CNY)。
  Future<String> _ledgerCurrency(int ledgerId) async {
    final ledger = await repo.getLedgerById(ledgerId);
    final c = ledger?.currency;
    return (c == null || c.isEmpty) ? 'CNY' : c.toUpperCase();
  }

  /// 本地是否已有 [quote] → [base] 的有效汇率(手动 override 或最新自动源)。
  /// 判定口径与 `mergeEffectiveRates` 一致:rate 能解析成正数才算有效。
  Future<bool> _hasLocalRate(String base, String quote) async {
    bool valid(String rate) => (double.tryParse(rate) ?? 0) > 0;
    try {
      final overrides = await repo.getOverrides(base);
      if (overrides.any((o) =>
          o.quoteCurrency.toUpperCase() == quote && valid(o.rate))) {
        return true;
      }
      final autos = await repo.getLatestAutoRates(base);
      return autos.any(
          (r) => r.quoteCurrency.toUpperCase() == quote && valid(r.rate));
    } catch (e) {
      // 查不了就当没有,交给 _ensureRateAvailable 兜(它自己也吞异常)
      logger.debug(_tag, '[汇率] 本地汇率检查失败,按「无」处理: $e');
      return false;
    }
  }

  /// 尽力把 [code] → 账本本位币的汇率拉到本地(A6)。
  ///
  /// 拉不到**不阻断**:自动截图/通知记账是无人值守的,阻断等于丢账。落库时
  /// repo 会退化成 `nativeAmount = amount`,恰好命中 L11 检测条件,用户在统计
  /// 页点一次「补折算」即可修正。手动记账那条路径仍然是阻断的(L8)。
  Future<void> _ensureRateAvailable(String code) async {
    final fn = ensureRate;
    if (fn == null) return;
    try {
      final ok = await fn(code);
      if (!ok) {
        logger.info(_tag, '[汇率] $code 拉取未成功,本笔按 1:1 暂记(L11 可补折算)');
      }
    } catch (e, st) {
      logger.warning(_tag, '[汇率] $code 拉取异常,本笔按 1:1 暂记', st);
      logger.debug(_tag, '[汇率] 异常详情: $e');
    }
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
