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
  SortType _currentSortType = SortType.timeDesc; // 默认时间倒序（最新在前）

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(_categoryProvider(widget.categoryId));
    final summaryAsync = ref.watch(_categorySummaryProvider(widget.categoryId));
    final transactionsAsync = ref.watch(_categoryTransactionsWithSortProvider((categoryId: widget.categoryId, sortType: _currentSortType)));
    
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
                    
                    // 如果迁移完成，刷新相关providers
                    if (result == true && mounted) {
                      ref.invalidate(_categoryProvider(widget.categoryId));
                      ref.invalidate(_categorySummaryProvider(widget.categoryId));
                      ref.invalidate(_categoryTransactionsProvider(widget.categoryId));
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
                    
                    // 如果编辑成功，刷新相关providers
                    if (result == true && mounted) {
                      ref.invalidate(_categoryProvider(widget.categoryId));
                      ref.invalidate(_categorySummaryProvider(widget.categoryId));
                      ref.invalidate(_categoryTransactionsProvider(widget.categoryId));
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
                _buildSortControls(),
                // 交易记录列表
                Expanded(
                  child: transactionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('加载失败: $error')),
                    data: (transactions) => _buildTransactionsList(transactions),
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

  Widget _buildSortControls() {
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
                    isSelected: _currentSortType == SortType.timeDesc,
                    onTap: () => _changeSortType(SortType.timeDesc),
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '时间↑',
                    isSelected: _currentSortType == SortType.timeAsc,
                    onTap: () => _changeSortType(SortType.timeAsc),
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '金额↓',
                    isSelected: _currentSortType == SortType.amountDesc,
                    onTap: () => _changeSortType(SortType.amountDesc),
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: '金额↑',
                    isSelected: _currentSortType == SortType.amountAsc,
                    onTap: () => _changeSortType(SortType.amountAsc),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeSortType(SortType newSortType) {
    setState(() {
      _currentSortType = newSortType;
    });
  }

  Widget _buildTransactionsList(List<db.Transaction> transactions) {
    if (transactions.isEmpty) {
      return AppEmpty(
        text: '暂无交易记录',
        subtext: '该分类下还没有任何交易记录',
      );
    }

    // 按日期分组，但保持原有的排序顺序（使用LinkedHashMap维持插入顺序）
    final Map<String, List<db.Transaction>> groupedTransactions = <String, List<db.Transaction>>{};
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.happenedAt.toLocal());
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    // 获取日期键并按需排序
    final sortedKeys = groupedTransactions.keys.toList();

    // 根据排序类型决定日期分组的显示顺序
    if (_currentSortType == SortType.amountDesc || _currentSortType == SortType.amountAsc) {
      // 金额排序时：按照第一个交易的金额来排序日期分组
      sortedKeys.sort((dateA, dateB) {
        final transactionsA = groupedTransactions[dateA]!;
        final transactionsB = groupedTransactions[dateB]!;

        if (transactionsA.isEmpty || transactionsB.isEmpty) return 0;

        // 用每组第一个交易的金额来比较（因为组内已经按金额排序）
        final amountA = transactionsA.first.amount;
        final amountB = transactionsB.first.amount;

        return _currentSortType == SortType.amountDesc
          ? amountB.compareTo(amountA)  // 降序
          : amountA.compareTo(amountB); // 升序
      });
    } else {
      // 时间排序时：按日期排序分组
      if (_currentSortType == SortType.timeDesc) {
        sortedKeys.sort((a, b) => b.compareTo(a)); // 最新日期在前
      } else {
        sortedKeys.sort((a, b) => a.compareTo(b)); // 最早日期在前
      }
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
            )),
          ],
        );
      },
    );
  }



  IconData _getTransactionIcon(db.Transaction transaction) {
    final categoryAsync = ref.read(_categoryProvider(widget.categoryId));
    final categoryName = categoryAsync.value?.name ?? widget.categoryName;
    // 使用与首页相同的图标获取逻辑
    return iconForCategory(categoryName);
  }
  
  String _getTransactionTitle(db.Transaction transaction) {
    final categoryAsync = ref.read(_categoryProvider(widget.categoryId));
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

// Provider for category data
final _categoryProvider = FutureProvider.family<db.Category?, int>((ref, categoryId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.categories)..where((c) => c.id.equals(categoryId))).getSingleOrNull();
});

// Provider for category summary data
final _categorySummaryProvider = FutureProvider.family<({int totalCount, double totalAmount, double averageAmount}), int>((ref, categoryId) async {
  final repo = ref.watch(repositoryProvider);
  return await repo.getCategorySummary(categoryId);
});

// Provider for category transactions with sorting
final _categoryTransactionsWithSortProvider = FutureProvider.family<List<db.Transaction>, ({int categoryId, SortType sortType})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);

  String sortBy;
  bool ascending;

  switch (params.sortType) {
    case SortType.timeAsc:
      sortBy = 'time';
      ascending = true;
      break;
    case SortType.timeDesc:
      sortBy = 'time';
      ascending = false;
      break;
    case SortType.amountAsc:
      sortBy = 'amount';
      ascending = true;
      break;
    case SortType.amountDesc:
      sortBy = 'amount';
      ascending = false;
      break;
  }

  return await repo.getTransactionsByCategoryWithSort(
    params.categoryId,
    sortBy: sortBy,
    ascending: ascending,
  );
});

// Provider for category transactions (kept for backward compatibility)
final _categoryTransactionsProvider = FutureProvider.family<List<db.Transaction>, int>((ref, categoryId) async {
  final repo = ref.watch(repositoryProvider);
  return await repo.getTransactionsByCategory(categoryId);
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