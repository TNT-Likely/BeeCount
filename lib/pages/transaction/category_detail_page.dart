import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../data/db.dart' as db;
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/category_icon.dart';
import '../../styles/tokens.dart';
import 'package:intl/intl.dart';
import '../category/category_edit_page.dart';
import '../category/category_migration_page.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../services/billing/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';

enum SortType { timeAsc, timeDesc, amountAsc, amountDesc }

class CategoryDetailPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final DateTime? startDate; // 周期开始时间（可选）
  final DateTime? endDate;   // 周期结束时间（可选）
  final String? periodLabel; // 周期标签（如"2024年11月"）
  final bool allLedgers; // true=全部账本(从分类管理进入)，false=当前账本(从明细进入)

  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.startDate,
    this.endDate,
    this.periodLabel,
    this.allLedgers = false,
  });

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  // 注意：不再需要SortType状态，因为现在由StateProvider管理

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(_categoryStreamProvider(widget.categoryId));
    final ledgerScope = widget.allLedgers ? null : ref.watch(currentLedgerIdProvider);
    final transactionsAsync = ref.watch(_categoryTransactionsWithSortProvider((categoryId: widget.categoryId, ledgerId: ledgerScope)));
    final currentSortType = ref.watch(_categorySortTypeProvider(widget.categoryId));

    // 如果有周期限制，需要筛选交易数据
    final filteredTransactionsAsync = transactionsAsync.when(
      loading: () => const AsyncValue<List<db.Transaction>>.loading(),
      error: (error, stack) => AsyncValue<List<db.Transaction>>.error(error, stack),
      data: (transactions) {
        if (widget.startDate != null && widget.endDate != null) {
          final filtered = transactions.where((t) {
            // 修复：使用 >= 和 < 来包含起始日期，排除结束日期的下一天
            return t.happenedAt.isAtSameMomentAs(widget.startDate!) ||
                   (t.happenedAt.isAfter(widget.startDate!) &&
                    t.happenedAt.isBefore(widget.endDate!));
          }).toList();
          return AsyncValue.data(filtered);
        }
        return AsyncValue.data(transactions);
      },
    );

    // 基于筛选后的数据计算汇总
    final summaryAsync = filteredTransactionsAsync.when(
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
    
    return Scaffold(
      body: Column(
        children: [
          categoryAsync.when(
            loading: () => PrimaryHeader(
              title: AppLocalizations.of(context).categoryDetailSummaryTitle, // "分类汇总"
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
              title: AppLocalizations.of(context).categoryDetailSummaryTitle,
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
              title: AppLocalizations.of(context).categoryDetailSummaryTitle,
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz_outlined),
                  tooltip: AppLocalizations.of(context).categoryMigrationTooltip,
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
                  tooltip: AppLocalizations.of(context).commonEdit,
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
                    child: Center(child: Text(AppLocalizations.of(context).categoryLoadFailed(error.toString()))),
                  ),
                  data: (summary) => _buildSummaryCard(summary),
                ),
                // 排序控件
                _buildSortControls(currentSortType),
                // 交易记录列表
                Expanded(
                  child: filteredTransactionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('${AppLocalizations.of(context).categoryDetailLoadFailed}: $error')),
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
    // 获取分类信息以确定颜色
    final categoryAsync = ref.watch(_categoryStreamProvider(widget.categoryId));
    final category = categoryAsync.value;
    final isIncome = category?.kind == 'income';

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
                  Expanded(
                    child: Text(
                      widget.periodLabel != null
                          ? '${CategoryUtils.getDisplayName(widget.categoryName, context)} · ${widget.periodLabel}'
                          : CategoryUtils.getDisplayName(widget.categoryName, context),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailTotalCount,
                      value: AppLocalizations.of(context).categoryMigrationTransactionLabel(summary.totalCount),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailTotalAmount,
                      value: summary.totalAmount,
                      isAmount: true,
                      color: isIncome
                        ? BeeTokens.incomeColor(context, ref)
                        : BeeTokens.expenseColor(context, ref),
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: AppLocalizations.of(context).categoryDetailAverageAmount,
                      value: summary.averageAmount,
                      isAmount: true,
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
            AppLocalizations.of(context).categoryDetailSortTitle,
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
                    label: AppLocalizations.of(context).categoryDetailSortTimeDesc,
                    isSelected: currentSortType == SortType.timeDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.timeDesc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortTimeAsc,
                    isSelected: currentSortType == SortType.timeAsc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.timeAsc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortAmountDesc,
                    isSelected: currentSortType == SortType.amountDesc,
                    onTap: () => ref.read(_categorySortTypeProvider(widget.categoryId).notifier).state = SortType.amountDesc,
                  ),
                  const SizedBox(width: 8),
                  _SortButton(
                    label: AppLocalizations.of(context).categoryDetailSortAmountAsc,
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
        text: AppLocalizations.of(context).categoryDetailNoTransactions,
        subtext: AppLocalizations.of(context).categoryDetailNoTransactionsSubtext,
      );
    }

    // 全部账本模式下，构建账本名映射，用于在交易项展示账本标签
    final ledgerNames = widget.allLedgers
        ? {for (final l in (ref.watch(ledgersStreamProvider).valueOrNull ?? [])) l.id: l.name}
        : const <int, String>{};

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
            final category = _getTransactionCategory();
            return TransactionListItem(
              icon: _getTransactionIcon(transaction),
              category: category,
              title: transaction.note ?? '',
              categoryName: CategoryUtils.getDisplayName(category?.name ?? widget.categoryName, context),
              ledgerName: ledgerNames[transaction.ledgerId],
              amount: transaction.amount,
              isExpense: transaction.type == 'expense',
              happenedAt: transaction.happenedAt,
              onTap: () async {
                final categoryData = ref.read(_categoryStreamProvider(widget.categoryId));
                await TransactionEditUtils.editTransaction(
                  context,
                  ref,
                  transaction,
                  categoryData.value,
                );
              },
              onDelete: () async {
                final repo = ref.read(repositoryProvider);
                final ledgerId = ref.read(currentLedgerIdProvider);

                try {
                  await repo.deleteTransaction(transaction.id);

                  // 统一处理：自动/手动同步与状态刷新（后台静默）
                  await PostProcessor.sync(ref, ledgerId: ledgerId);

                  // 刷新：账本笔数与全局统计
                  ref.invalidate(countsForLedgerProvider(ledgerId));
                  ref.read(statsRefreshProvider.notifier).state++;
                  ref.read(budgetRefreshProvider.notifier).state++;
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, '${AppLocalizations.of(context).categoryDetailDeleteFailed}: $e');
                  }
                }
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
            ...dayTransactions.map((transaction) {
              final category = _getTransactionCategory();
              return TransactionListItem(
              icon: _getTransactionIcon(transaction),
              category: category,
              title: transaction.note ?? '',
              categoryName: CategoryUtils.getDisplayName(category?.name ?? widget.categoryName, context),
              ledgerName: ledgerNames[transaction.ledgerId],
              amount: transaction.amount,
              isExpense: transaction.type == 'expense',
              happenedAt: transaction.happenedAt,
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
              onDelete: () async {
                final repo = ref.read(repositoryProvider);
                final ledgerId = ref.read(currentLedgerIdProvider);

                try {
                  await repo.deleteTransaction(transaction.id);

                  // 统一处理：自动/手动同步与状态刷新（后台静默）
                  await PostProcessor.sync(ref, ledgerId: ledgerId);

                  // 刷新：账本笔数与全局统计
                  ref.invalidate(countsForLedgerProvider(ledgerId));
                  ref.read(statsRefreshProvider.notifier).state++;
                  ref.read(budgetRefreshProvider.notifier).state++;
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, '${AppLocalizations.of(context).categoryDetailDeleteFailed}: $e');
                  }
                }
              },
            );
            }),
          ],
        );
      },
    );
  }



  db.Category? _getTransactionCategory() {
    final categoryAsync = ref.read(_categoryStreamProvider(widget.categoryId));
    return categoryAsync.value;
  }

  IconData _getTransactionIcon(db.Transaction transaction) {
    final categoryAsync = ref.read(_categoryStreamProvider(widget.categoryId));
    final category = categoryAsync.value;
    final categoryName = category?.name ?? widget.categoryName;
    // 使用统一的图标获取逻辑,优先使用分类对象的icon字段
    return getCategoryIconData(category: category, categoryName: categoryName);
  }

}

class _SummaryItem extends ConsumerWidget {
  final String label;
  final dynamic value; // 可以是 String 或 double
  final Color color;
  final bool isAmount; // 是否为金额类型

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget valueWidget;
    if (isAmount && value is double) {
      // 金额类型,使用 AmountText
      valueWidget = AmountText(
        value: value as double,
        signed: false,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      // 其他类型,直接显示字符串
      valueWidget = Text(
        value.toString(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: [
        valueWidget,
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

// 基础数据流：监听分类下交易变化（仅当前账本）
final _categoryTransactionsStreamProvider = StreamProvider.family<List<db.Transaction>, ({int categoryId, int? ledgerId})>((ref, params) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTransactionsByCategory(params.categoryId, ledgerId: params.ledgerId);
});

// 排序状态管理
final _categorySortTypeProvider = StateProvider.family<SortType, int>((ref, categoryId) {
  return SortType.timeDesc; // 默认时间倒序
});

// 派生数据：排序后的交易列表（自动响应排序状态变化）
final _categoryTransactionsWithSortProvider = Provider.family<AsyncValue<List<db.Transaction>>, ({int categoryId, int? ledgerId})>((ref, params) {
  final transactionsAsync = ref.watch(_categoryTransactionsStreamProvider(params));
  final sortType = ref.watch(_categorySortTypeProvider(params.categoryId));

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