import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_provider_manager.dart';
import 'database_providers.dart';
import 'theme_providers.dart';
import 'statistics_providers.dart';
import 'budget_providers.dart';
import 'font_scale_provider.dart';
import 'update_providers.dart';
import 'smart_billing_providers.dart';
import '../data/db.dart';
import '../services/data/recurring_transaction_service.dart';
import '../services/billing/post_processor.dart';
import '../services/system/logger_service.dart';
import '../ai/providers/ai_constants.dart';
import '../services/platform/app_link_service.dart';
import 'security_providers.dart';

// 底部导航索引（0: 明细, 1: 图表, 2: 账本, 3: 我的）
final bottomTabIndexProvider = StateProvider<int>((ref) => 0);

// AppLink 待处理动作（用于通知 UI 层执行导航）
final pendingAppLinkActionProvider = StateProvider<AppLinkAction?>((ref) => null);

// 手动记账待处理类型（expense/income，配合 newTransaction action 使用）
final pendingNewTransactionTypeProvider = StateProvider<String?>((ref) => null);

// 首页滚动到顶部触发器（每次改变值时触发滚动）
final homeScrollToTopProvider = StateProvider<int>((ref) => 0);

// 首页切换到 Stream 模式触发器（用户交互时触发）
final homeSwitchToStreamProvider = StateProvider<int>((ref) => 0);

// Currently selected month (first day), default to now
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// 视角：'month' 或 'year'
final selectedViewProvider = StateProvider<String>((ref) => 'month');

// 检查更新状态 - 防止重复点击
final checkUpdateLoadingProvider = StateProvider<bool>((ref) => false);

// 下载进度状态
final downloadProgressProvider = StateProvider<UpdateProgress?>((ref) => null);

// ---------- Analytics 提示持久化（本地 SharedPreferences） ----------
final analyticsHeaderHintDismissedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('analytics_header_hint_dismissed') ?? false;
});

final analyticsChartHintDismissedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('analytics_chart_hint_dismissed') ?? false;
});

class AnalyticsHintsSetter {
  Future<void> dismissHeader() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_header_hint_dismissed', true);
  }

  Future<void> dismissChart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_chart_hint_dismissed', true);
  }
}

// ---------- FAB 长按提示持久化 ----------
final fabSpeedDialTipDismissedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('fab_speed_dial_tip_dismissed') ?? false;
});

class FabSpeedDialTipSetter {
  Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fab_speed_dial_tip_dismissed', true);
  }
}

final fabSpeedDialTipSetterProvider = Provider<FabSpeedDialTipSetter>((ref) {
  return FabSpeedDialTipSetter();
});

final analyticsHintsSetterProvider = Provider<AnalyticsHintsSetter>((ref) {
  return AnalyticsHintsSetter();
});

// 应用初始化状态
enum AppInitState {
  splash, // 显示启屏页
  loading, // 正在初始化
  ready // 初始化完成，显示主应用
}

// 应用初始化状态Provider
final appInitStateProvider =
    StateProvider<AppInitState>((ref) => AppInitState.splash);

// 搜索页面金额范围筛选开关持久化
final searchAmountFilterEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('search_amount_filter_enabled') ?? false;
});

class SearchSettingsSetter {
  Future<void> setAmountFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('search_amount_filter_enabled', enabled);
  }
}

final searchSettingsSetterProvider = Provider<SearchSettingsSetter>((ref) {
  return SearchSettingsSetter();
});

// 账户功能启用状态持久化
final accountFeatureEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('account_feature_enabled') ?? true;
});

class AccountFeatureSetter {
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('account_feature_enabled', enabled);
  }
}

final accountFeatureSetterProvider = Provider<AccountFeatureSetter>((ref) {
  return AccountFeatureSetter();
});

/// 完整的交易展示数据（含分类、账户、标签、附件数量）
/// 用于首页列表一次性加载，避免二次查询闪烁
///
/// D 方案后:account / toAccount 是 watchTransactionsWithCategory* JOIN 直接
/// 拿到的 Drift Account 对象,不再依赖 Splash 单独 getAccountsByIds 拼名字。
/// accountName / toAccountName 保留是为了字符串路径(import / export / diff)
/// 的向后兼容,等下游全部切到 account 对象后可以删。
typedef TransactionDisplayItem = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount,
  List<Tag> tags,
  int attachmentCount,
  String? accountName,
  String? toAccountName,
});

// 缓存的完整交易数据Provider（含标签、附件、账户，用于首屏快速展示）
final cachedTransactionsProvider =
    StateProvider<List<TransactionDisplayItem>?>((ref) => null);

// 缓存的交易数据Provider（仅含分类，兼容旧版本）
final cachedTransactionsWithCategoryProvider =
    StateProvider<List<({Transaction t, Category? category, Account? account, Account? toAccount})>?>((ref) => null);

// 应用初始化Provider - 管理数据预加载
final appSplashInitProvider = FutureProvider<void>((ref) async {
  const tag = 'Splash';
  logger.info(tag, '开始启屏页预加载');
  final startTime = DateTime.now();
  var stepTime = startTime;

  try {
    // 确保基础providers已初始化
    logger.info(tag, '初始化基础配置...');
    await Future.wait([
      ref.watch(primaryColorInitProvider.future),
      ref.watch(themeModeInitProvider.future),
      ref.watch(darkModePatternStyleInitProvider.future),
      ref.watch(appInitProvider.future),
      ref.watch(fontScaleInitProvider.future),
      ref.watch(hideAmountsInitProvider.future),
      ref.watch(compactAmountInitProvider.future),
      ref.watch(showTransactionTimeInitProvider.future),
      ref.watch(smartBillingAutoTagsInitProvider.future),
      ref.watch(smartBillingAutoAttachmentInitProvider.future),
      ref.watch(incomeExpenseColorSchemeInitProvider.future),
      ref.watch(securityInitProvider.future),
    ]);
    logger.info(tag, '基础配置初始化完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');
    stepTime = DateTime.now();

    // 获取 repository
    final repo = ref.read(repositoryProvider);

    // 预加载当前账本的关键数据
    final ledgerId = ref.read(currentLedgerIdProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // 并行预加载：月度统计 + 交易列表（分别计时）
    final monthlyParams = (ledgerId: ledgerId, month: currentMonth);

    // 包装每个任务以记录各自耗时
    Future<T> timed<T>(String name, Future<T> future) async {
      final start = DateTime.now();
      final result = await future;
      logger.info(tag, '$name: ${DateTime.now().difference(start).inMilliseconds}ms');
      return result;
    }

    // 首屏预加载条数限制（只加载前 N 条，加快启动速度）
    const preloadLimit = 20;

    final results = await Future.wait([
      timed('月度统计', ref.read(monthlyTotalsProvider(monthlyParams).future)),
      // 只查询前 N 条，而非全部
      timed('交易列表(前$preloadLimit条)', repo.getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: preloadLimit)),
      // 预加载预算概览，避免首页进度条闪现
      timed('预算概览', ref.read(budgetOverviewProvider.future)),
    ]);

    final monthlyResult = results[0] as (double, double);
    final transactionsWithCategory = results[1] as List<({Transaction t, Category? category, Account? account, Account? toAccount})>;

    ref.read(lastMonthlyTotalsProvider(monthlyParams).notifier).state = monthlyResult;
    // 不再预加载完整列表，让 Stream 自己加载
    logger.info(tag, '并行预加载完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms, 首屏${transactionsWithCategory.length}条');
    stepTime = DateTime.now();

    // 只为首屏数据加载标签、附件数量和账户信息
    final transactionIds = transactionsWithCategory.map((t) => t.t.id).toList();

    // 收集所有需要查询的账户ID
    final accountIds = <int>{};
    for (final item in transactionsWithCategory) {
      if (item.t.accountId != null) accountIds.add(item.t.accountId!);
      if (item.t.toAccountId != null) accountIds.add(item.t.toAccountId!);
    }

    final detailResults = await Future.wait([
      timed('标签数据', repo.getTagsForTransactions(transactionIds)),
      timed('附件数量', repo.getAttachmentCountsForTransactions(transactionIds)),
      timed('账户数据', repo.getAccountsByIds(accountIds.toList())),
    ]);

    final tagsMap = detailResults[0] as Map<int, List<Tag>>;
    final attachmentCounts = detailResults[1] as Map<int, int>;
    final accountsList = detailResults[2] as List<Account>;

    // 构建账户ID到名称的映射
    final accountNameMap = <int, String>{};
    for (final account in accountsList) {
      accountNameMap[account.id] = account.name;
    }
    logger.info(tag, '详情数据加载完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');
    stepTime = DateTime.now();

    // 组装完整的交易展示数据。account / toAccount 直接用 watch 时 JOIN 拿到
    // 的对象(D 方案);accountName 走 item.account?.name 优先,fallback 到
    // accountNameMap(Editor 共享账本场景:主表 accountId 是 null,要走
    // accountSyncIdOverride → SharedLedgerAccounts 反查)。
    final fullTransactions = transactionsWithCategory.map((item) {
      final accName = item.account?.name ??
          (item.t.accountId != null
              ? accountNameMap[item.t.accountId!]
              : null);
      final toAccName = item.toAccount?.name ??
          (item.t.toAccountId != null
              ? accountNameMap[item.t.toAccountId!]
              : null);
      return (
        t: item.t,
        category: item.category,
        account: item.account,
        toAccount: item.toAccount,
        tags: tagsMap[item.t.id] ?? <Tag>[],
        attachmentCount: attachmentCounts[item.t.id] ?? 0,
        accountName: accName,
        toAccountName: toAccName,
      );
    }).toList();

    ref.read(cachedTransactionsProvider.notifier).state = fullTransactions;

    // 账本统计异步加载（不阻塞启动）
    Future.microtask(() async {
      final start = DateTime.now();
      await ref.read(countsForLedgerProvider(ledgerId).future);
      logger.info(tag, '账本统计(异步): ${DateTime.now().difference(start).inMilliseconds}ms');
    });

    // 生成待处理的周期交易
    try {
      final generatedLedgerIds = await RecurringTransactionService.generatePendingTransactionsStatic(
        repository: repo,
        verbose: false,
      );
      logger.info(tag, '周期交易生成完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');

      // 统一后处理：刷新UI + 触发云同步（如果有生成交易）
      for (final genLedgerId in generatedLedgerIds) {
        await PostProcessor.runR(ref, ledgerId: genLedgerId);
      }
    } catch (e, stackTrace) {
      logger.error(tag, '周期交易生成失败', e, stackTrace);
    }
  } catch (e, stackTrace) {
    logger.error(tag, '预加载数据失败', e, stackTrace);
  }

  // 计算数据预加载耗时
  final dataLoadTime = DateTime.now().difference(startTime);
  logger.info(tag, '预加载总耗时: ${dataLoadTime.inMilliseconds}ms，切换到主应用');
  ref.read(appInitStateProvider.notifier).state = AppInitState.ready;
});

// 是否应该显示欢迎页面的Provider
final shouldShowWelcomeProvider = StateProvider<bool>((ref) => false);

// 初始化检查是否需要显示欢迎页面
final welcomeCheckProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final welcomeShown = prefs.getBool('welcome_shown') ?? false;
  if (!welcomeShown) {
    print('👋 首次启动，需要展示欢迎页面');
    ref.read(shouldShowWelcomeProvider.notifier).state = true;
    return true;
  }
  return false;
});

// 默认收入账户ID持久化
final defaultIncomeAccountIdProvider =
    FutureProvider.autoDispose<int?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getInt('default_income_account_id');
});

// 默认支出账户ID持久化
final defaultExpenseAccountIdProvider =
    FutureProvider.autoDispose<int?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getInt('default_expense_account_id');
});

class DefaultAccountSetter {
  Future<void> setDefaultIncomeAccountId(int? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await prefs.remove('default_income_account_id');
    } else {
      await prefs.setInt('default_income_account_id', accountId);
    }
  }

  Future<void> setDefaultExpenseAccountId(int? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await prefs.remove('default_expense_account_id');
    } else {
      await prefs.setInt('default_expense_account_id', accountId);
    }
  }
}

final defaultAccountSetterProvider = Provider<DefaultAccountSetter>((ref) {
  return DefaultAccountSetter();
});

// AI小助手开关状态持久化
final aiAssistantEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool(AIConstants.keyAiBillExtractionEnabled) ?? true; // 默认开启
});

class AIAssistantSetter {
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AIConstants.keyAiBillExtractionEnabled, enabled);
    // 同 ai_config_providers 的 _saveToPrefs —— 让 "AI 助手开关"
    // 改变也能 push 到 server,跨设备和 web 拿到同样的值。
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (_) {}
  }
}

final aiAssistantSetterProvider = Provider<AIAssistantSetter>((ref) {
  return AIAssistantSetter();
});

