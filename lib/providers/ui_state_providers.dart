import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_provider_manager.dart';
import 'database_providers.dart';
import 'theme_providers.dart';
import 'feature_highlight_providers.dart';
import 'currency_providers.dart';
import 'statistics_providers.dart';
import 'budget_providers.dart';
import 'font_scale_provider.dart';
import 'update_providers.dart';
import 'smart_billing_providers.dart';
import '../data/db.dart';
import '../utils/month_range.dart';
import '../services/data/recurring_transaction_service.dart';
import '../services/billing/post_processor.dart';
import '../services/system/logger_service.dart';
import '../ai/providers/ai_constants.dart';
import '../services/platform/app_link_service.dart';
import 'security_providers.dart';
import '../models/home_transaction_preview.dart';
import 'home_startup_preview_provider.dart';
export '../models/home_transaction_preview.dart' show TransactionDisplayItem;

// 底部导航索引（0: 明细, 1: 图表, 2: 账本, 3: 我的）
final bottomTabIndexProvider = StateProvider<int>((ref) => 0);

// AppLink 待处理动作（用于通知 UI 层执行导航）
final pendingAppLinkActionProvider =
    StateProvider<AppLinkAction?>((ref) => null);

// 手动记账待处理类型（expense/income，配合 newTransaction action 使用）
final pendingNewTransactionTypeProvider = StateProvider<String?>((ref) => null);

// 手动记账待处理的预填分类 id（配合 newTransaction action 使用，来自小组件
// 「快速记账」深链 beecount://new?type=...&category=<id>）
final pendingNewTransactionCategoryIdProvider =
    StateProvider<int?>((ref) => null);

// beecount://open?page=... 深链的待处理目标页面（assets/budget/detail），
// 配合 AppLinkAction.open 使用
final pendingOpenPageProvider = StateProvider<String?>((ref) => null);

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

// Legacy compatibility cache. The first Home receives the full, one-shot
// startup snapshot instead; later navigation always reads current data.
final cachedTransactionsProvider =
    StateProvider<List<TransactionDisplayItem>?>((ref) => null);

// 缓存的交易数据Provider（仅含分类，兼容旧版本）
final cachedTransactionsWithCategoryProvider = StateProvider<
    List<
        ({
          Transaction t,
          Category? category,
          Account? account,
          Account? toAccount
        })>?>((ref) => null);

// 应用初始化Provider - 管理数据预加载
final appSplashInitProvider = FutureProvider<void>((ref) async {
  const tag = 'Splash';
  logger.info(tag, '开始启屏页预加载');
  final startTime = DateTime.now();
  var stepTime = startTime;
  final handoff = ref.read(homeStartupPreviewHandoffProvider)..clear();
  var disposed = false;
  ref.onDispose(() => disposed = true);

  try {
    // 确保基础providers已初始化
    logger.info(tag, '初始化基础配置...');
    await Future.wait([
      ref.watch(primaryColorInitProvider.future),
      ref.watch(themeModeInitProvider.future),
      ref.watch(appInitProvider.future),
      ref.watch(fontScaleInitProvider.future),
      ref.watch(hideAmountsInitProvider.future),
      ref.watch(compactAmountInitProvider.future),
      ref.watch(skinAnimationInitProvider.future),
      ref.watch(featureHighlightInitProvider.future),
      ref.watch(showTransactionTimeInitProvider.future),
      ref.watch(noteDisplayModeInitProvider.future),
      ref.watch(noteHistoryPreferencesInitProvider.future),
      ref.watch(smartBillingAutoTagsInitProvider.future),
      ref.watch(smartBillingAutoAttachmentInitProvider.future),
      ref.watch(incomeExpenseColorSchemeInitProvider.future),
      ref.watch(displayNameInitProvider.future),
      ref.watch(baseCurrencyInitProvider.future),
      ref.watch(headerSkinInitProvider.future),
      ref.watch(securityInitProvider.future),
    ]);
    logger.info(tag,
        '基础配置初始化完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');
    stepTime = DateTime.now();

    if (disposed) return;

    // Finish startup writes before preparing the snapshot that Home will use.
    // Publishing the earlier rows would omit newly generated recurring bills.
    try {
      final generatedLedgerIds =
          await RecurringTransactionService.generatePendingTransactionsStatic(
        repository: ref.read(repositoryProvider),
        verbose: false,
      );
      if (disposed) return;
      for (final ledgerId in generatedLedgerIds) {
        await PostProcessor.runR(ref, ledgerId: ledgerId);
        if (disposed) return;
      }
      logger.info(tag,
          '周期交易生成完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms');
    } catch (e, stackTrace) {
      logger.error(tag, '周期交易生成失败', e, stackTrace);
    }

    if (disposed) return;
    // Configuration can replace the repository or selected ledger while an
    // async read is running. Only publish the final, still-current scope.
    while (true) {
      final repo = ref.read(repositoryProvider);

      // 预加载当前账本的关键数据
      final ledgerId = ref.read(currentLedgerIdProvider);
      final now = DateTime.now();
      // 月份周期标签:startDay>1 时今天可能属于「上个标签月」(如 6月5日属 5月周期)
      final ledgerRow = await repo.getLedgerById(ledgerId);
      final startDay = (ledgerRow?.monthStartDay ?? 1).clamp(1, 28);
      final currentMonth = labelForDate(now, startDay);
      ref.read(selectedMonthProvider.notifier).state = currentMonth;

      // 并行预加载：月度统计 + 交易列表（分别计时）
      final monthlyParams = (ledgerId: ledgerId, month: currentMonth);
      ref.invalidate(monthlyTotalsProvider(monthlyParams));
      ref.invalidate(budgetOverviewProvider);

      // 包装每个任务以记录各自耗时
      Future<T> timed<T>(String name, Future<T> future) async {
        final start = DateTime.now();
        final result = await future;
        logger.info(
            tag, '$name: ${DateTime.now().difference(start).inMilliseconds}ms');
        return result;
      }

      // 首屏预加载条数限制（只加载前 N 条，加快启动速度）
      const preloadLimit = 20;

      final results = await Future.wait([
        timed('月度统计', ref.read(monthlyTotalsProvider(monthlyParams).future)),
        // 只查询前 N 条，而非全部
        timed('完整首屏(前$preloadLimit条)',
            handoff.prepare(repo, ledgerId, ref.read(databaseProvider))),
        // 预加载预算概览，避免首页进度条闪现
        timed('预算概览', ref.read(budgetOverviewProvider.future)),
        timed('账本信息', ref.read(currentLedgerProvider.future)),
      ]);

      final monthlyResult = results[0] as (double, double);
      final preview = results[1] as HomeTransactionPreview;
      if (disposed) return;
      if (!identical(repo, ref.read(repositoryProvider)) ||
          ledgerId != ref.read(currentLedgerIdProvider) ||
          !identical(handoff.peek(repo, ledgerId)?.preview, preview)) {
        continue;
      }

      ref.read(lastMonthlyTotalsProvider(monthlyParams).notifier).state =
          monthlyResult;
      ref.read(cachedTransactionsProvider.notifier).state = preview.rows;
      logger.info(tag,
          '并行预加载完成: ${DateTime.now().difference(stepTime).inMilliseconds}ms, 完整首屏${preview.rows.length}条');
      stepTime = DateTime.now();

      // 账本统计异步加载（不阻塞启动）
      Future.microtask(() async {
        if (disposed) return;
        final start = DateTime.now();
        await ref.read(countsForLedgerProvider(ledgerId).future);
        if (disposed) return;
        logger.info(tag,
            '账本统计(异步): ${DateTime.now().difference(start).inMilliseconds}ms');
      });

      break;
    }
  } catch (e, stackTrace) {
    if (disposed) return;
    handoff.clear();
    logger.error(tag, '预加载数据失败', e, stackTrace);
    // Keep the startup boundary retryable. A failed read must not become a
    // "ready" Home with an empty list, a second spinner or stale cache.
    rethrow;
  }

  // 计算数据预加载耗时
  final dataLoadTime = DateTime.now().difference(startTime);
  logger.info(tag, '预加载总耗时: ${dataLoadTime.inMilliseconds}ms，切换到主应用');
  if (!disposed) {
    ref.read(appInitStateProvider.notifier).state = AppInitState.ready;
  }
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
