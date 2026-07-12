import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/repositories/budget_repository.dart';
import '../providers.dart';

/// 首页预算卡片显示开关（持久化）
const _budgetCardEnabledKey = 'home_budget_card_enabled';

final homeBudgetCardEnabledProvider =
    StateNotifierProvider<_BudgetCardEnabledNotifier, bool>(
  (ref) => _BudgetCardEnabledNotifier(),
);

class _BudgetCardEnabledNotifier extends StateNotifier<bool> {
  _BudgetCardEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_budgetCardEnabledKey) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_budgetCardEnabledKey, value);
  }
}

/// 预算刷新触发器
final budgetRefreshProvider = StateProvider<int>((ref) => 0);

/// 当前账本的总预算
final totalBudgetProvider = FutureProvider<Budget?>((ref) async {
  ref.watch(budgetRefreshProvider);

  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  return repo.getTotalBudget(ledgerId);
});

/// 当前账本的所有预算
final allBudgetsProvider = FutureProvider<List<Budget>>((ref) async {
  ref.watch(budgetRefreshProvider);

  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  return repo.getAllBudgets(ledgerId);
});

/// 当前账本的预算概览
final budgetOverviewProvider = FutureProvider<BudgetOverview?>((ref) async {
  ref.watch(budgetRefreshProvider);

  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);
  final now = DateTime.now();

  return repo.getBudgetOverview(ledgerId, now);
});

/// 分类预算列表
final categoryBudgetsProvider =
    FutureProvider<List<CategoryBudgetUsage>>((ref) async {
  ref.watch(budgetRefreshProvider);

  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);
  final now = DateTime.now();

  return repo.getCategoryBudgetUsages(ledgerId, now);
});

/// 监听预算变化
final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  return repo.watchBudgets(ledgerId);
});

/// 指定分类的预算使用情况
final categoryBudgetUsageProvider =
    FutureProvider.family<CategoryBudgetUsage?, int>((ref, categoryId) async {
  ref.watch(budgetRefreshProvider);

  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  final budget = await repo.getBudgetByCategory(ledgerId, categoryId);
  if (budget == null) return null;

  final now = DateTime.now();
  final usage = await repo.getBudgetUsage(budget.id, now);

  // 获取分类信息
  final categories = await repo.getAllCategories();
  final category = categories.where((c) => c.id == categoryId).firstOrNull;
  if (category == null) return null;

  return CategoryBudgetUsage(
    budgetId: budget.id,
    categoryId: categoryId,
    categoryName: category.name,
    categoryIcon: category.icon,
    usage: usage,
  );
});
