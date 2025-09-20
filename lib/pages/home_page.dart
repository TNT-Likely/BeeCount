import 'package:beecount/widgets/biz/bee_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider;
import '../data/db.dart';
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../utils/sync_helpers.dart';
import '../utils/transaction_edit_utils.dart';
import 'category_detail_page.dart';
import '../widgets/category_icon.dart';

// 优化版首页 - 使用FlutterListView实现精准定位和丝滑跳转
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late FlutterListViewController _listController;
  bool _isJumping = false;
  List<({Transaction t, Category? category})> _transactions = [];
  final Map<String, int> _dateIndexMap = {}; // 日期到列表索引的映射
  final Map<int, String> _indexDateMap = {}; // 索引到日期的映射
  List<dynamic> _flatItems = []; // 保存扁平化的项目列表

  // 可见性管理
  final Set<String> _visibleHeaders = {}; // 当前可见的日期头部
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _listController = FlutterListViewController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _listController.dispose();
    super.dispose();
  }

  // 构建日期索引映射，用于快速定位（基于扁平化后的列表）
  void _buildDateIndexMap(List<dynamic> flatItems) {
    _dateIndexMap.clear();
    _indexDateMap.clear();

    for (int i = 0; i < flatItems.length; i++) {
      final item = flatItems[i];
      final type = item.$1 as String;

      if (type == 'header') {
        final dateKey = item.$2 as String;
        // 记录每个日期头部的索引
        _dateIndexMap[dateKey] = i;
        _indexDateMap[i] = dateKey;
      }
    }
  }

  // 找到目标月份的第一个交易索引
  int? _findMonthFirstIndex(DateTime targetMonth) {
    final monthKey =
        '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

    // 查找该月份的任意一天
    for (final entry in _dateIndexMap.entries) {
      if (entry.key.startsWith(monthKey)) {
        return entry.value;
      }
    }

    return null;
  }

  // 精准月份跳转 - 使用FlutterListView的jumpToIndex
  Future<void> _jumpToTargetMonth(DateTime targetMonth) async {
    if (_isJumping) return; // 防止重复跳转

    setState(() {
      _isJumping = true;
    });

    try {
      // 查找目标月份的第一个交易索引
      final targetIndex = _findMonthFirstIndex(targetMonth);

      if (targetIndex != null && mounted) {
        // 使用FlutterListViewController的正确方法
        _listController.sliverController.jumpToIndex(targetIndex);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJumping = false;
        });
      }
    }
  }

  // 日期头部可见性变化
  void _onHeaderVisibilityChanged(String dateKey, bool isVisible) {
    if (_isJumping) return;

    if (isVisible) {
      _visibleHeaders.add(dateKey);
    } else {
      _visibleHeaders.remove(dateKey);
    }

    // 防抖更新月份
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _updateCurrentMonth();
    });
  }

  // 更新当前月份
  void _updateCurrentMonth() {
    if (_isJumping || !mounted || _visibleHeaders.isEmpty) return;

    try {
      // 获取最顶部的可见日期头部（按日期排序，取最新的）
      final sortedDates = _visibleHeaders.toList()
        ..sort((a, b) => b.compareTo(a));
      final topDateKey = sortedDates.first;

      final dateParts = topDateKey.split('-');
      if (dateParts.length != 3) return;

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final detectedMonth = DateTime(year, month, 1);

      // 更新选中月份
      final currentSelected = ref.read(selectedMonthProvider);
      if (currentSelected.year != detectedMonth.year ||
          currentSelected.month != detectedMonth.month) {
        ref.read(selectedMonthProvider.notifier).state = detectedMonth;
      }
    } catch (e) {
      // 忽略错误，继续正常运行
    }
  }

  // FlutterListView不需要手动计算偏移量，直接使用jumpToIndex即可！

  // 日期选择处理
  Future<void> _handleDateSelection() async {
    final month = ref.read(selectedMonthProvider);
    final res = await showWheelDatePicker(
      context,
      initial: month,
      mode: WheelDatePickerMode.ym,
      maxDate: DateTime.now(),
    );

    if (res != null) {
      final targetMonth = DateTime(res.year, res.month, 1);
      ref.read(selectedMonthProvider.notifier).state = targetMonth;

      // 使用FlutterListView的精准跳转
      await _jumpToTargetMonth(targetMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final cachedData = ref.watch(cachedTransactionsWithCategoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final hide = ref.watch(hideAmountsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Consumer(builder: (context, ref, _) {
            ref.watch(headerStyleProvider);
            final hide = ref.watch(hideAmountsProvider);
            return PrimaryHeader(
              title: '',
              showTitleSection: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 头部 - 保持原有设计
                  Row(
                    children: [
                      IconButton(
                        tooltip: '选择日期',
                        onPressed: _isJumping ? null : _handleDateSelection,
                        icon: _isJumping
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: BeeColors.primaryText,
                                ),
                              )
                            : const Icon(Icons.calendar_month,
                                size: 18, color: BeeColors.primaryText),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BeeIcon(
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 32),
                              Text(
                                '蜜蜂记账',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: BeeColors.primaryText,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: hide ? '显示金额' : '隐藏金额',
                        onPressed: () {
                          final cur = ref.read(hideAmountsProvider);
                          ref.read(hideAmountsProvider.notifier).state = !cur;
                        },
                        icon: Icon(
                          hide
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: BeeColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行 - 月份显示和统计
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isJumping ? null : _handleDateSelection,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${month.year}年',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: BeeColors.black54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${month.month.toString().padLeft(2, '0')}月',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: BeeColors.primaryText,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 36,
                        color: BeeColors.divider,
                      ),
                      Expanded(child: _HeaderCenterSummary(hide: hide)),
                    ],
                  ),
                ],
              ),
              bottom: null,
            );
          }),
          const SizedBox(height: 0),
          Expanded(
            child: StreamBuilder<List<({Transaction t, Category? category})>>(
              stream: repo.transactionsWithCategoryAll(ledgerId: ledgerId),
              builder: (context, snapshot) {
                // 优先使用流数据，否则使用缓存数据，避免显示loading
                final joined = snapshot.hasData ? snapshot.data! : (cachedData ?? []);
                _transactions = joined; // 保存交易数据

                // 按天分组 - 保持原有逻辑
                final dateFmt = DateFormat('yyyy-MM-dd');
                final groups =
                    <String, List<({Transaction t, Category? category})>>{};
                for (final item in joined) {
                  final dt = item.t.happenedAt.toLocal();
                  final key =
                      dateFmt.format(DateTime(dt.year, dt.month, dt.day));
                  groups.putIfAbsent(key, () => []).add(item);
                }
                final sortedKeys = groups.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                // 无数据时展示空状态
                if (sortedKeys.isEmpty) {
                  return const AppEmpty(
                    text: '还没有记账',
                    subtext: '点击底部加号，马上记一笔',
                  );
                }

                // 构建扁平的项目列表
                _flatItems = <dynamic>[];
                for (final key in sortedKeys) {
                  final list = groups[key]!;
                  // 添加日期头部
                  _flatItems.add(('header', key, list));
                  // 添加所有交易项
                  for (final item in list) {
                    _flatItems.add(('transaction', item, list));
                  }
                }

                // 构建索引映射（基于扁平化后的列表）
                _buildDateIndexMap(_flatItems);

                // 使用FlutterListView替代ListView.builder
                return FlutterListView(
                  controller: _listController,
                  physics: const BouncingScrollPhysics(),
                  delegate: FlutterListViewDelegate(
                    (BuildContext context, int index) {
                      final item = _flatItems[index];
                      final type = item.$1 as String;

                      if (type == 'header') {
                        // 渲染日期头部
                        final dateKey = item.$2 as String;
                        final list = item.$3
                            as List<({Transaction t, Category? category})>;
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
                        return VisibilityDetector(
                          key: Key('header-$dateKey'),
                          onVisibilityChanged: (VisibilityInfo info) {
                            // 当可见比例大于50%时认为可见
                            _onHeaderVisibilityChanged(
                                dateKey, info.visibleFraction > 0.5);
                          },
                          child: Column(
                            children: [
                              if (!isFirst)
                                Divider(height: 1, color: Colors.grey[200]),
                              DaySectionHeader(
                                dateText: dateKey,
                                income: dayIncome,
                                expense: dayExpense,
                                hide: hide,
                              ),
                            ],
                          ),
                        );
                      } else {
                        // 渲染交易项
                        final it =
                            item.$2 as ({Transaction t, Category? category});
                        final allItemsInDay = item.$3
                            as List<({Transaction t, Category? category})>;
                        final isExpense = it.t.type == 'expense';
                        final categoryName = it.category?.name ?? '未分类';
                        final subtitle = it.t.note ?? '';

                        // 检查是否是当天最后一项
                        final isLastInGroup =
                            allItemsInDay.last.t.id == it.t.id;

                        return Dismissible(
                          key: Key('tx-${it.t.id}-$index'), // 添加索引避免key冲突
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: Colors.red,
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await AppDialog.confirm<bool>(
                                  context,
                                  title: '删除确认',
                                  message: '确定要删除这条记账吗？',
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
                            handleLocalChange(ref,
                                ledgerId: curLedger, background: true);

                            if (context.mounted) {
                              showToast(context, '已删除');
                            }
                          },
                          child: Column(
                            children: [
                              TransactionListItem(
                                icon: iconForCategory(categoryName),
                                title: subtitle.isNotEmpty
                                    ? subtitle
                                    : categoryName,
                                categoryName:
                                    subtitle.isNotEmpty ? null : categoryName,
                                amount: it.t.amount,
                                isExpense: isExpense,
                                hide: hide,
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
                                AppDivider.short(
                                    indent: 56 + 16, endIndent: 16),
                            ],
                          ),
                        );
                      }
                    },
                    childCount: _flatItems.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCenterSummary extends ConsumerWidget {
  final bool hide;
  const _HeaderCenterSummary({required this.hide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final params = (ledgerId: ledgerId, month: month);

    ref.watch(monthlyTotalsProvider(params));
    final cachedTotals = ref.watch(lastMonthlyTotalsProvider(params));
    final (income, expense) = cachedTotals ?? (0.0, 0.0);
    final balance = income - expense;

    Widget item(String title, double value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                textAlign: TextAlign.left, style: AppTextTokens.label(context)),
            const SizedBox(height: 2),
            Text(
              hide ? '****' : formatMoneyCompact(value, maxDecimals: 2),
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BeeColors.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ) ??
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: BeeColors.primaryText,
                  ),
            ),
          ],
        );
    return Row(
      children: [
        Expanded(child: item('收入', income)),
        Expanded(child: item('支出', expense)),
        Expanded(child: item('结余', balance)),
      ],
    );
  }
}
