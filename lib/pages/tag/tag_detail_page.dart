import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart' as db;
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/category_icon.dart';
import '../../styles/tokens.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../l10n/app_localizations.dart';
import 'tag_edit_page.dart';

/// 标签详情页
/// 显示标签统计和关联交易列表
class TagDetailPage extends ConsumerStatefulWidget {
  final int tagId;
  final String tagName;
  final bool allLedgers; // true=全部账本(从标签管理进入)，false=当前账本(从明细进入)

  const TagDetailPage({
    super.key,
    required this.tagId,
    required this.tagName,
    this.allLedgers = false,
  });

  @override
  ConsumerState<TagDetailPage> createState() => _TagDetailPageState();
}

class _TagDetailPageState extends ConsumerState<TagDetailPage> {
  // 缓存分类数据
  Map<int, db.Category> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = ref.read(repositoryProvider);
    final categories = await repo.getAllCategories();
    if (mounted) {
      setState(() {
        _categoryCache = {for (var c in categories) c.id: c};
      });
    }
  }

  Color _parseTagColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    try {
      String hex = colorHex;
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tagAsync = ref.watch(_tagStreamProvider(widget.tagId));
    final ledgerScope = widget.allLedgers ? null : ref.watch(currentLedgerIdProvider);
    final statsAsync = ref.watch(_tagStatsProvider((tagId: widget.tagId, ledgerId: ledgerScope)));
    final transactionsAsync = ref.watch(_tagTransactionsStreamProvider((tagId: widget.tagId, ledgerId: ledgerScope)));

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // Header
          tagAsync.when(
            loading: () => PrimaryHeader(
              title: l10n.tagDetailTitle,
              showBack: true,
            ),
            error: (error, stack) => PrimaryHeader(
              title: l10n.tagDetailTitle,
              showBack: true,
            ),
            data: (tag) => PrimaryHeader(
              title: l10n.tagDetailTitle,
              showBack: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.commonEdit,
                  onPressed: tag != null
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TagEditPage(tag: tag),
                            ),
                          );
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.commonDelete,
                  onPressed: tag != null
                      ? () => _confirmDelete(tag, l10n)
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // 标签信息和统计卡片
                tagAsync.when(
                  loading: () => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Container(
                    height: 140,
                    margin: const EdgeInsets.all(16),
                    child: Center(child: Text('${l10n.commonError}: $error')),
                  ),
                  data: (tag) {
                    if (tag == null) {
                      return Container(
                        height: 140,
                        margin: const EdgeInsets.all(16),
                        child: Center(child: Text(l10n.tagNotFound)),
                      );
                    }
                    return statsAsync.when(
                      loading: () => _buildSummaryCard(tag, null, l10n),
                      error: (error, stack) => _buildSummaryCard(tag, null, l10n),
                      data: (stats) => _buildSummaryCard(tag, stats, l10n),
                    );
                  },
                ),
                // 交易列表标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: BeeTokens.textTertiary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.tagDetailTransactionList,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BeeTokens.textTertiary(context),
                            ),
                      ),
                    ],
                  ),
                ),
                // 交易列表
                Expanded(
                  child: transactionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text('${l10n.commonError}: $error'),
                    ),
                    data: (transactions) => _buildTransactionsList(transactions, l10n),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    db.Tag tag,
    ({int count, double expense, double income})? stats,
    AppLocalizations l10n,
  ) {
    final tagColor = _parseTagColor(tag.color);

    return Container(
      margin: const EdgeInsets.all(16),
      child: SectionCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标签信息
              Row(
                children: [
                  // 颜色指示器
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tag.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 统计信息
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: l10n.tagDetailTotalCount,
                      value: stats != null
                          ? l10n.tagTransactionCount(stats.count)
                          : '-',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: l10n.tagDetailTotalExpense,
                      value: stats?.expense ?? 0.0,
                      isAmount: true,
                      color: BeeTokens.expenseColor(context, ref),
                    ),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: l10n.tagDetailTotalIncome,
                      value: stats?.income ?? 0.0,
                      isAmount: true,
                      color: BeeTokens.incomeColor(context, ref),
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

  Widget _buildTransactionsList(
    List<db.Transaction> transactions,
    AppLocalizations l10n,
  ) {
    if (transactions.isEmpty) {
      return AppEmpty(
        text: l10n.tagDetailNoTransactions,
        subtext: l10n.tagDetailNoTransactionsHint,
      );
    }

    // 全部账本模式下，构建账本名映射，用于在交易项展示账本标签
    final ledgerNames = widget.allLedgers
        ? {for (final l in (ref.watch(ledgersStreamProvider).valueOrNull ?? [])) l.id: l.name}
        : const <int, String>{};

    // 按日期分组
    final Map<String, List<db.Transaction>> groupedTransactions = {};
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.happenedAt.toLocal());
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    final sortedKeys = groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

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
              final category = _categoryCache[transaction.categoryId];
              final categoryName = CategoryUtils.getDisplayName(category?.name, context);

              // 和首页保持一致：分类名常驻，备注接在后面
              return TransactionListItem(
                icon: getCategoryIconData(category: category, categoryName: categoryName),
                category: category,
                title: transaction.note ?? '',
                categoryName: categoryName,
                ledgerName: ledgerNames[transaction.ledgerId],
                amount: transaction.amount,
                isExpense: transaction.type == 'expense',
                happenedAt: transaction.happenedAt,
                onTap: () async {
                  await TransactionEditUtils.editTransaction(
                    context,
                    ref,
                    transaction,
                    category,
                  );
                },
                onDelete: () async {
                  await _deleteTransaction(transaction, l10n);
                },
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(db.Transaction transaction, AppLocalizations l10n) async {
    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    try {
      await repo.deleteTransaction(transaction.id);

      await PostProcessor.sync(ref, ledgerId: ledgerId);

      ref.invalidate(countsForLedgerProvider(ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      ref.read(tagListRefreshProvider.notifier).state++;
    } catch (e) {
      if (mounted) {
        showToast(context, '${l10n.commonError}: $e');
      }
    }
  }

  void _confirmDelete(db.Tag tag, AppLocalizations l10n) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.tagDeleteConfirmTitle,
      message: l10n.tagDeleteConfirmMessage(tag.name),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(repositoryProvider);
      await repo.deleteTag(tag.id);
      ref.read(tagListRefreshProvider.notifier).state++;

      if (mounted) {
        showToast(context, l10n.tagDeleteSuccess);
        Navigator.of(context).pop();
      }
    }
  }
}

class _SummaryItem extends ConsumerWidget {
  final String label;
  final dynamic value;
  final Color color;
  final bool isAmount;

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
      valueWidget = AmountText(
        value: value as double,
        signed: false,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      );
    } else {
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
                color: BeeTokens.textTertiary(context),
              ),
        ),
      ],
    );
  }
}

// ===== Providers =====

/// 监听标签详情
final _tagStreamProvider = StreamProvider.family<db.Tag?, int>((ref, tagId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTag(tagId);
});

/// 获取标签统计信息
final _tagStatsProvider = FutureProvider.family<({int count, double expense, double income}), ({int tagId, int? ledgerId})>((ref, params) async {
  ref.watch(tagListRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return await repo.getTagStats(params.tagId, ledgerId: params.ledgerId);
});

/// 监听标签下的交易
final _tagTransactionsStreamProvider = StreamProvider.family<List<db.Transaction>, ({int tagId, int? ledgerId})>((ref, params) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchTransactionsByTag(params.tagId, ledgerId: params.ledgerId);
});
