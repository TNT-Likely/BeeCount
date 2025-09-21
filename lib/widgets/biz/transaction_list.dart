import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/design.dart';
import '../../utils/sync_helpers.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../utils/category_utils.dart';
import '../category_icon.dart';
import '../../pages/category_detail_page.dart';
import '../../l10n/app_localizations.dart';

/// 可复用的交易列表组件
/// 支持显示分组的交易列表，包含日期头部和交易项
class TransactionList extends ConsumerStatefulWidget {
  /// 交易数据
  final List<({Transaction t, Category? category})> transactions;

  /// 是否隐藏金额
  final bool hideAmounts;

  /// 是否启用可见性检测用于月份跳转（主要用于首页）
  final bool enableVisibilityTracking;

  /// 月份变化回调（用于首页月份跳转逻辑）
  final Function(String dateKey, bool isVisible)? onDateVisibilityChanged;

  /// 自定义空状态显示
  final Widget? emptyWidget;

  /// 列表控制器（可选，用于精准跳转）
  final FlutterListViewController? controller;

  const TransactionList({
    super.key,
    required this.transactions,
    required this.hideAmounts,
    this.enableVisibilityTracking = false,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.controller,
  });

  @override
  ConsumerState<TransactionList> createState() => TransactionListState();
}

class TransactionListState extends ConsumerState<TransactionList> {
  late FlutterListViewController _controller;
  List<dynamic> _flatItems = []; // 扁平化的项目列表
  final Map<String, int> _dateIndexMap = {}; // 日期到列表索引的映射

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FlutterListViewController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose(); // 只在我们创建的controller时才dispose
    }
    super.dispose();
  }

  /// 跳转到指定月份
  bool jumpToMonth(DateTime targetMonth) {
    final monthKey =
        '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

    // 查找该月份的任意一天
    for (final entry in _dateIndexMap.entries) {
      if (entry.key.startsWith(monthKey)) {
        try {
          _controller.sliverController.jumpToIndex(entry.value);
          return true;
        } catch (e) {
          // 跳转失败，返回false
          return false;
        }
      }
    }

    return false; // 没有找到目标月份
  }

  /// 构建扁平化的项目列表
  void _buildFlatItems() {
    final transactions = widget.transactions;

    // 按天分组
    final dateFmt = DateFormat('yyyy-MM-dd');
    final groups = <String, List<({Transaction t, Category? category})>>{};
    for (final item in transactions) {
      final dt = item.t.happenedAt.toLocal();
      final key = dateFmt.format(DateTime(dt.year, dt.month, dt.day));
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // 构建扁平的项目列表和日期索引映射
    _flatItems = <dynamic>[];
    _dateIndexMap.clear();

    for (final key in sortedKeys) {
      final list = groups[key]!;
      // 记录日期头部在扁平化列表中的索引
      _dateIndexMap[key] = _flatItems.length;
      // 添加日期头部
      _flatItems.add(('header', key, list));
      // 添加所有交易项
      for (final item in list) {
        _flatItems.add(('transaction', item, list));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildFlatItems();

    // 无数据时展示空状态
    if (_flatItems.isEmpty) {
      return widget.emptyWidget ??
        AppEmpty(
          text: AppLocalizations.of(context).commonEmpty,
          subtext: AppLocalizations.of(context).homeNoRecords,
        );
    }

    // 使用FlutterListView渲染列表
    return FlutterListView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      delegate: FlutterListViewDelegate(
        (BuildContext context, int index) {
          final item = _flatItems[index];
          final type = item.$1 as String;

          if (type == 'header') {
            // 渲染日期头部
            final dateKey = item.$2 as String;
            final list = item.$3 as List<({Transaction t, Category? category})>;
            double dayIncome = 0, dayExpense = 0;
            for (final it in list) {
              if (it.t.type == 'income') {
                dayIncome += it.t.amount;
              }
              if (it.t.type == 'expense') {
                dayExpense += it.t.amount;
              }
            }
            final isFirst = index == 0;

            Widget header = Column(
              children: [
                if (!isFirst) Divider(height: 1, color: Colors.grey[200]),
                DaySectionHeader(
                  dateText: dateKey,
                  income: dayIncome,
                  expense: dayExpense,
                  hide: widget.hideAmounts,
                ),
              ],
            );

            // 如果启用可见性跟踪，则包装VisibilityDetector
            if (widget.enableVisibilityTracking && widget.onDateVisibilityChanged != null) {
              header = VisibilityDetector(
                key: Key('header-$dateKey'),
                onVisibilityChanged: (VisibilityInfo info) {
                  // 当可见比例大于50%时认为可见
                  widget.onDateVisibilityChanged!(dateKey, info.visibleFraction > 0.5);
                },
                child: header,
              );
            }

            return header;
          } else {
            // 渲染交易项
            final it = item.$2 as ({Transaction t, Category? category});
            final allItemsInDay = item.$3 as List<({Transaction t, Category? category})>;
            final isExpense = it.t.type == 'expense';
            final categoryName = CategoryUtils.getDisplayName(it.category?.name, context);
            final subtitle = it.t.note ?? '';

            // 检查是否是当天最后一项
            final isLastInGroup = allItemsInDay.last.t.id == it.t.id;

            return Dismissible(
              key: Key('tx-${it.t.id}-$index'), // 添加索引避免key冲突
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await AppDialog.confirm<bool>(
                      context,
                      title: AppLocalizations.of(context).deleteConfirmTitle,
                      message: AppLocalizations.of(context).deleteConfirmMessage,
                    ) ??
                    false;
              },
              onDismissed: (direction) async {
                final db = ref.read(databaseProvider);
                await (db.delete(db.transactions)
                      ..where((t) => t.id.equals(it.t.id)))
                    .go();

                if (!context.mounted) return;
                final curLedger = ref.read(currentLedgerIdProvider);
                ref.invalidate(countsForLedgerProvider(curLedger));
                ref.read(statsRefreshProvider.notifier).state++;
                handleLocalChange(ref, ledgerId: curLedger, background: true);

                if (context.mounted) {
                  showToast(context, AppLocalizations.of(context).ledgersDeleted);
                }
              },
              child: Column(
                children: [
                  TransactionListItem(
                    icon: iconForCategory(categoryName),
                    title: subtitle.isNotEmpty ? subtitle : categoryName,
                    categoryName: subtitle.isNotEmpty ? null : categoryName,
                    amount: it.t.amount,
                    isExpense: isExpense,
                    hide: widget.hideAmounts,
                    onTap: () async {
                      await TransactionEditUtils.editTransaction(
                        context,
                        ref,
                        it.t,
                        it.category,
                      );
                    },
                    onCategoryTap: it.category?.id != null
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailPage(
                                  categoryId: it.category!.id,
                                  categoryName: categoryName,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                  if (!isLastInGroup)
                    AppDivider.short(indent: 56 + 16, endIndent: 16),
                ],
              ),
            );
          }
        },
        childCount: _flatItems.length,
      ),
    );
  }
}