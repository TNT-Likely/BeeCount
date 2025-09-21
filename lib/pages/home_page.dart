import 'package:beecount/widgets/biz/bee_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'dart:async';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider;
import '../data/db.dart';
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import 'search_page.dart';

// 优化版首页 - 使用FlutterListView实现精准定位和丝滑跳转
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late FlutterListViewController _listController;
  bool _isJumping = false;
  final GlobalKey<TransactionListState> _transactionListKey = GlobalKey<TransactionListState>();

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

  // 精准月份跳转 - 使用TransactionList组件的跳转功能
  Future<void> _jumpToTargetMonth(DateTime targetMonth) async {
    if (_isJumping) return; // 防止重复跳转

    setState(() {
      _isJumping = true;
    });

    try {
      // 使用TransactionList组件的跳转方法
      final transactionListState = _transactionListKey.currentState;
      if (transactionListState != null && mounted) {
        transactionListState.jumpToMonth(targetMonth);
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
                  // 头部 - 重新设计布局
                  Row(
                    children: [
                      // 左上角：隐藏金额按钮
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
                          size: 20,
                          color: BeeColors.primaryText,
                        ),
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
                      // 右上角：搜索按钮
                      IconButton(
                        tooltip: '搜索',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.search,
                          size: 20,
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
                                const SizedBox(width: 4),
                                // 月份旁边的向下三角形（日期选择）
                                _isJumping
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: BeeColors.primaryText,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: BeeColors.black54,
                                      ),
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

                // 使用新的可复用TransactionList组件
                return TransactionList(
                  key: _transactionListKey,
                  transactions: joined,
                  hideAmounts: hide,
                  enableVisibilityTracking: true,
                  onDateVisibilityChanged: _onHeaderVisibilityChanged,
                  controller: _listController,
                  emptyWidget: const AppEmpty(
                    text: '还没有记账',
                    subtext: '点击底部加号，马上记一笔',
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
