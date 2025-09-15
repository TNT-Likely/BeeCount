import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_providers.dart';
import 'theme_providers.dart';
import 'statistics_providers.dart';
import 'font_scale_provider.dart';
import '../data/db.dart';

// 底部导航索引（0: 明细, 1: 图表, 2: 账本, 3: 我的）
final bottomTabIndexProvider = StateProvider<int>((ref) => 0);

// Currently selected month (first day), default to now
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// 视角：'month' 或 'year'
final selectedViewProvider = StateProvider<String>((ref) => 'month');

// 检查更新状态 - 防止重复点击
final checkUpdateLoadingProvider = StateProvider<bool>((ref) => false);

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

final analyticsHintsSetterProvider = Provider<AnalyticsHintsSetter>((ref) {
  return AnalyticsHintsSetter();
});

// 应用初始化状态
enum AppInitState {
  splash,    // 显示启屏页
  loading,   // 正在初始化
  ready      // 初始化完成，显示主应用
}

// 应用初始化状态Provider
final appInitStateProvider = StateProvider<AppInitState>((ref) => AppInitState.splash);

// 缓存的交易数据Provider（用于首屏快速展示）
final cachedTransactionsWithCategoryProvider = StateProvider<List<({Transaction t, Category? category})>?>((ref) => null);

// 应用初始化Provider - 管理数据预加载
final appSplashInitProvider = FutureProvider<void>((ref) async {
  print('🚀 开始启屏页预加载');
  final startTime = DateTime.now();
  
  try {
    // 确保基础providers已初始化
    print('📱 初始化基础配置...');
    await Future.wait([
      // 等待主题色初始化
      ref.watch(primaryColorInitProvider.future),
      // 等待应用配置初始化
      ref.watch(appInitProvider.future),
      // 等待字体缩放初始化
      ref.watch(fontScaleInitProvider.future),
    ]);
    print('✅ 基础配置初始化完成');
    
    // 确保数据库已初始化
    ref.read(databaseProvider);
    print('🗄️ 数据库初始化完成');
    
    // 预加载当前账本的关键数据
    final ledgerId = ref.read(currentLedgerIdProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    print('📊 开始预加载账本数据, ledgerId=$ledgerId');
    
    // 预加载本月统计数据
    final monthlyParams = (ledgerId: ledgerId, month: currentMonth);
    final monthlyResult = await ref.read(monthlyTotalsProvider(monthlyParams).future);
    ref.read(lastMonthlyTotalsProvider(monthlyParams).notifier).state = monthlyResult;
    print('💰 月度统计预加载完成: $monthlyResult');
    
    // 预加载账本总数统计  
    final countsResult = await ref.read(countsForLedgerProvider(ledgerId).future);
    print('🔢 账本统计预加载完成: $countsResult');
    
    // 预加载首屏交易数据（包含分类信息）
    final repo = ref.read(repositoryProvider);
    final recentTransactionsWithCategory = await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
    ref.read(cachedTransactionsWithCategoryProvider.notifier).state = recentTransactionsWithCategory;
    print('💳 交易列表预加载完成: ${recentTransactionsWithCategory.length}条记录');
    
  } catch (e) {
    print('❌ 预加载数据失败: $e');
  }
  
  // 计算数据预加载耗时
  final dataLoadTime = DateTime.now().difference(startTime);
  print('⏱️ 数据预加载耗时: ${dataLoadTime.inMilliseconds}ms');
  
  // 确保启屏页展示时间至少2秒
  const minDisplayDuration = Duration(seconds: 2);
  final remainingTime = minDisplayDuration - dataLoadTime;
  
  if (remainingTime.inMilliseconds > 0) {
    print('⏱️ 启屏页还需展示${remainingTime.inMilliseconds}ms以满足最小展示时间...');
    await Future.delayed(remainingTime);
  }
  
  // 标记初始化完成
  print('🎉 预加载完成，切换到主应用');
  ref.read(appInitStateProvider.notifier).state = AppInitState.ready;
});