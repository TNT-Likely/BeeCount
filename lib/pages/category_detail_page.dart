import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../providers/database_providers.dart';
import '../data/db.dart' as db;
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';
import '../widgets/category_icon.dart';
import '../utils/format_utils.dart';
import 'package:intl/intl.dart';
import 'category_edit_page.dart';
import 'category_migration_page.dart';
import '../utils/transaction_edit_utils.dart';

enum SortType { timeAsc, timeDesc, amountAsc, amountDesc }

class CategoryDetailPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  
  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });
  
  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  // 注意：不再需要SortType状态，因为现在由StateProvider管理

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(_categoryStreamProvider(widget.categoryId));
    final summaryAsync = ref.watch(_categorySummaryProvider(widget.categoryId));
    final transactionsAsync = ref.watch(_categoryTransactionsWithSortProvider(widget.categoryId));
    final currentSortType = ref.watch(_categorySortTypeProvider(widget.categoryId));
    
    return Scaffold(
      body: Column(
        children: [
          categoryAsync.when(
            loading: () => PrimaryHeader(
              title: widget.categoryName, // 显示传入的名称作为fallback
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  onPressed: null, // 加载时禁用
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: null, // 加载时禁用
                ),
              ],
            ),
            error: (error, stack) => PrimaryHeader(
              title: widget.categoryName,
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  onPressed: null, // 错误时禁用
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: null, // 错误时禁用
                ),
              ],
            ),
            data: (category) => PrimaryHeader(
              title: category?.name ?? widget.categoryName, // 使用最新的分类名称
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  tooltip: '迁移分类',
                  onPressed: category != null ? () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryMigrationPage(
                          preselectedFromCategory: category,
                        ),
                      ),
                    );
                    
                    // 如果迁移完成，数据会自动通过Stream更新，无需手动刷新
                    if (result == true && mounted) {
                      // 响应式设计：数据库变化会自动推送到UI
                    }
                  } : null,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑分类',
                  onPressed: category != null ? () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryEditPage(
                          category: category,
                          kind: category.kind,
                        ),
                      ),
                    );
                    
                    // 如果编辑成功，数据会自动通过Stream更新，无需手动刷新
                    if (result == true && mounted) {
                      // 响应式设计：数据库变化会自动推送到UI
                    }
                  } : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // 汇总信息卡片
                summaryAsync.when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Container(
                    height: 120,
                    margin: const EdgeInsets.all(16),
                    child: Center(child: Text('加载失败: $error')),
                  ),
                  data: (summary) => _buildSummaryCard(summary),
                ),
                // 排序控件
                _buildSortControls(currentSortType),
                // 交易记录列表
                Expanded(
                  child: transactionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('加载失败: $error')),
                    data: (transactions) => _buildTransactionsList(transactions, currentSortType),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(({int totalCount, double totalAmount, double averageAmount}) summary) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SectionCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '分类汇总',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: '总笔数',
                      value: '${summary.totalCount}笔',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: '总金额',
                      value: formatBalance(summary.totalAmount),
                      color: summary.totalAmount >= 0 
                        ? Colors.green 
                        : Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: '平均金额',
                      value: formatBalance(summary.averageAmount),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortControls(SortType currentSortType) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.sort,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            '排序',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SortButton(
                    label: '时间↓',
                    isSelected: currentSortType == SortType.timeDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.timeDesc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '时间↑',
                    isSelected: currentSortType == SortType.timeAsc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.timeAsc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '金额↓',
                    isSelected: currentSortType == SortType.amountDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.amountDesc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '金额↑',
                    isSelected: currentSortType == SortType.amountAsc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.amountAsc,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTransactionsList(List<db.Transaction> transactions, SortType currentSortType) {
    if (transactions.isEmpty) {
      return AppEmpty(
        text: '暂无交易记录',
        subtext: '该分类下还没有任何交易记录',
      );
    }

    // 金额排序时：预计算UI列表，避免动态插入导致卡顿
    if (currentSortType == SortType.amountDesc || currentSortType == SortType.amountAsc) {
      // 先计算每个日期的统计数据（避免重复计算）
      final Map<String, ({double expense, double income})> dateStats = {};
      for (final transaction in transactions) {
        final dateKey = DateFormat('yyyy-MM-dd').format(transaction.happenedAt.toLocal());
        final current = dateStats[dateKey] ?? (expense: 0.0, income: 0.0);
        dateStats[dateKey] = transaction.type == 'expense'
          ? (expense: current.expense + transaction.amount, income: current.income)
          : (expense: current.expense, income: current.income + transaction.amount);
      }

      // 预构建显示项列表
      final List<({bool isHeader, String? dateKey, db.Transaction? transaction})> displayItems = [];
      String? lastDateKey;

      for (final transaction in transactions) {
        final dateKey = DateFormat('yyyy-MM-dd').format(transaction.happenedAt.toLocal());

        // 当日期改变时，添加日期头
        if (lastDateKey != dateKey) {
          displayItems.add((isHeader: true, dateKey: dateKey, transaction: null));
          lastDateKey = dateKey;
        }

        // 添加交易项
        displayItems.add((isHeader: false, dateKey: null, transaction: transaction));
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];

          if (item.isHeader) {
            final stats = dateStats[item.dateKey!]!;
            return DaySectionHeader(
              dateText: item.dateKey!,
              expense: stats.expense,
              income: stats.income,
            );
          } else {
            final transaction = item.transaction!;
            return TransactionListItem(
              icon: _getTransactionIcon(transaction),
              title: _getTransactionTitle(transaction),
              amount: transaction.amount,
              isExpense: transaction.type == 'expense',
              onTap: () async {
                final categoryData = ref.read(_categoryStreamProvider(widget.categoryId));
                await TransactionEditUtils.editTransaction(
                  context,
                  ref,
                  transaction,
                  categoryData.value,
                );
              },
            );
          }
        },
      );
    }

    // 时间排序时：按日期分组，然后按时间排序日期分组
    final Map<String, List<db.Transaction>> groupedTransactions = <String, List<db.Transaction>>{};
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.happenedAt.toLocal());
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    final sortedKeys = groupedTransactions.keys.toList();
    // 时间排序时：按日期排序分组
    if (currentSortType == SortType.timeDesc) {
      sortedKeys.sort((a, b) => b.compareTo(a)); // 最新日期在前
    } else {
      sortedKeys.sort((a, b) => a.compareTo(b)); // 最早日期在前
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTransactions = groupedTransactions[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DaySectionHeader(
              dateText: dateKey,
              expense: dayTransactions
                  .where((t) => t.type == 'expense')
                  .fold(0.0, (sum, t) => sum + t.amount),
              income: dayTransactions
                  .where((t) => t.type == 'income')
                  .fold(0.0, (sum, t) => sum + t.amount),
            ),
            ...dayTransactions.map((transaction) => TransactionListItem(
              icon: _getTransactionIcon(transaction),
              title: _getTransactionTitle(transaction),
              amount: transaction.amount,
              isExpense: transaction.type == 'expense',
              onTap: () async {
                final categoryData = ref.read(_categoryStreamProvider(widget.categoryId));
                await TransactionEditUtils.editTransaction(
                  context,
                  ref,
                  transaction,
                  categoryData.value,
                );
                // 注意：现在无需手动刷新！
                // 数据库变化会自动通过Stream推送到UI
              },
            )),
          ],
        );
      },
    );
  }



  IconData _getTransactionIcon(db.Transaction transaction) {
    final categoryAsync = ref.read(_categoryStreamProvider(widget.categoryId));
    final categoryName = categoryAsync.value?.name ?? widget.categoryName;
    // 使用与首页相同的图标获取逻辑
    return iconForCategory(categoryName);
  }

  String _getTransactionTitle(db.Transaction transaction) {
    final categoryAsync = ref.read(_categoryStreamProvider(widget.categoryId));
    final categoryName = categoryAsync.value?.name ?? widget.categoryName;
    // 优先显示备注，无备注时显示分类名
    return transaction.note?.isNotEmpty == true
      ? transaction.note!
      : categoryName;
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// ===== 响应式Provider设计 =====

// 基础数据流：监听分类信息变化
final _categoryStreamProvider = StreamProvider.family<db.Category?, int>((ref, categoryId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchCategory(categoryId);
});

// 基础数据流：监听分类下交易变化
final _categoryTransactionsStreamProvider = StreamProvider.family<List<db.Transaction>, int>((ref, categoryId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTransactionsByCategory(categoryId);
});

// 排序状态管理
final _categorySortTypeProvider = StateProvider.family<SortType, int>((ref, categoryId) {
  return SortType.timeDesc; // 默认时间倒序
});

// 派生数据：排序后的交易列表（自动响应排序状态变化）
final _categoryTransactionsWithSortProvider = Provider.family<AsyncValue<List<db.Transaction>>, int>((ref, categoryId) {
  final transactionsAsync = ref.watch(_categoryTransactionsStreamProvider(categoryId));
  final sortType = ref.watch(_categorySortTypeProvider(categoryId));

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (transactions) {
      final sorted = List<db.Transaction>.from(transactions);

      switch (sortType) {
        case SortType.timeAsc:
          sorted.sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
          break;
        case SortType.timeDesc:
          sorted.sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
          break;
        case SortType.amountAsc:
          sorted.sort((a, b) => a.amount.compareTo(b.amount));
          break;
        case SortType.amountDesc:
          sorted.sort((a, b) => b.amount.compareTo(a.amount));
          break;
      }

      return AsyncValue.data(sorted);
    },
  );
});

// 派生数据：汇总统计（自动基于交易数据计算）
final _categorySummaryProvider = Provider.family<AsyncValue<({int totalCount, double totalAmount, double averageAmount})>, int>((ref, categoryId) {
  final transactionsAsync = ref.watch(_categoryTransactionsStreamProvider(categoryId));

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
    data: (transactions) {
      final totalCount = transactions.length;
      final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);
      final averageAmount = totalCount > 0 ? totalAmount / totalCount : 0.0;

      return AsyncValue.data((
        totalCount: totalCount,
        totalAmount: totalAmount,
        averageAmount: averageAmount,
      ));
    },
  );
});

class _SortButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}