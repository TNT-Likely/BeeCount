import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// wheel_date_picker exported via ui barrel
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../providers.dart';
import '../styles/colors.dart';
import '../widgets/ui/ui.dart';
import '../widgets/charts/line_chart.dart';
import '../widgets/analytics/analytics_summary.dart';
import '../widgets/analytics/category_rank_row.dart';
import '../widgets/ui/capsule_switcher.dart';
import 'category_detail_page.dart';

class Analytics2Page extends ConsumerStatefulWidget {
  const Analytics2Page({super.key});

  @override
  ConsumerState<Analytics2Page> createState() => _Analytics2PageState();
}

class _Analytics2PageState extends ConsumerState<Analytics2Page> {
  String _scope = 'month'; // month | year | all
  // 固定为汇总视角，移除支出/收入单独视角
  bool _localHeaderDismissed = false; // 本地快速隐藏，实际持久化在 provider 中
  bool _localChartDismissed = false;

  // 汇总视角下的激活状态：'all'（默认汇总）, 'expense'（仅支出）, 'income'（仅收入）
  String _summaryActiveType = 'all';

  // 切换支出线激活状态
  void _toggleExpenseLine() {
    print('支出线点击');
    setState(() {
      if (_summaryActiveType == 'all') {
        // 汇总模式：隐藏支出线，只显示收入
        _summaryActiveType = 'income';
      } else if (_summaryActiveType == 'expense') {
        // 仅支出模式：重新激活收入线，回到汇总模式
        _summaryActiveType = 'income';
      } else {
        // 仅收入模式：激活支出线，回到汇总模式
        _summaryActiveType = 'all';
      }
    });
  }

  // 切换收入线激活状态
  void _toggleIncomeLine() {
    print('收入线点击');
    setState(() {
      if (_summaryActiveType == 'all') {
        // 汇总模式：隐藏收入线，只显示支出
        _summaryActiveType = 'expense';
      } else if (_summaryActiveType == 'income') {
        // 仅收入模式：重新激活支出线，回到汇总模式
        _summaryActiveType = 'expense';
      } else {
        // 仅支出模式：激活收入线，回到汇总模式
        _summaryActiveType = 'all';
      }
    });
  }

  // 支出线是否激活
  bool get _expenseLineActive =>
      _summaryActiveType == 'all' || _summaryActiveType == 'expense';

  // 收入线是否激活
  bool get _incomeLineActive =>
      _summaryActiveType == 'all' || _summaryActiveType == 'income';

  Color _getCategoryColor(BuildContext context, String? itemType) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 汇总视角下根据类型和激活状态返回颜色
    if (itemType != null) {
      if (itemType == 'income') {
        // 收入：激活时用绿色，非激活时用灰色
        return _incomeLineActive ? Colors.green : Colors.grey.shade400;
      } else if (itemType == 'expense') {
        // 支出：激活时用红色，非激活时用灰色
        return _expenseLineActive ? Colors.red : Colors.grey.shade400;
      }
    }
    return primaryColor;
  }

  // 处理整个页面的横滑切换时间周期
  void _handlePeriodSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      // 左滑：下一个周期
      _navigateToNextPeriod();
    } else if (velocity > 200) {
      // 右滑：上一个周期
      _navigateToPreviousPeriod();
    }
  }

  // 切换到下一个周期
  void _navigateToNextPeriod() {
    final currentMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();

    if (_scope == 'month') {
      final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      // 不能滑动到未来的月份
      if (nextMonth.year < now.year ||
          (nextMonth.year == now.year && nextMonth.month <= now.month)) {
        ref.read(selectedMonthProvider.notifier).state = nextMonth;
      }
    } else if (_scope == 'year') {
      final nextYear = DateTime(currentMonth.year + 1);
      // 不能滑动到未来的年份
      if (nextYear.year <= now.year) {
        ref.read(selectedMonthProvider.notifier).state = nextYear;
      }
    }
    // 全部时间范围不支持切换
  }

  // 切换到上一个周期
  void _navigateToPreviousPeriod() {
    final currentMonth = ref.read(selectedMonthProvider);
    if (_scope == 'month') {
      final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      ref.read(selectedMonthProvider.notifier).state = prevMonth;
    } else if (_scope == 'year') {
      final prevYear = DateTime(currentMonth.year - 1);
      ref.read(selectedMonthProvider.notifier).state = prevYear;
    }
    // 全部时间范围不支持切换
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final selMonth = ref.watch(selectedMonthProvider);
    // 统计刷新 tick：当有新增/编辑/删除时我们会 +1，这里监听以触发重建和重新拉取
    ref.watch(statsRefreshProvider);

    // 时间范围
    late DateTime start;
    late DateTime end;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_scope == 'month') {
      start = DateTime(selMonth.year, selMonth.month, 1);
      final monthEnd = DateTime(selMonth.year, selMonth.month + 1, 1);
      // 当前月份：只到今天；历史月份：到月末
      final isCurrentMonth =
          selMonth.year == now.year && selMonth.month == now.month;
      end = isCurrentMonth ? today.add(const Duration(days: 1)) : monthEnd;
    } else if (_scope == 'year') {
      start = DateTime(selMonth.year, 1, 1);
      final yearEnd = DateTime(selMonth.year + 1, 1, 1);
      // 当前年份：只到今天；历史年份：到年末
      final isCurrentYear = selMonth.year == now.year;
      end = isCurrentYear ? today.add(const Duration(days: 1)) : yearEnd;
    } else {
      start = DateTime(1970, 1, 1);
      end = today.add(const Duration(days: 1));
    }

    // 固定使用汇总视角
    final Future<dynamic> seriesFuture =
        _getSummarySeriesFuture(_scope, ledgerId, selMonth, start, end);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: _summaryActiveType == 'expense'
                ? '支出分析'
                : _summaryActiveType == 'income'
                    ? '收入分析'
                    : '图表分析',
            leadingIcon: Icons.bar_chart_outlined,
            leadingPlain: true,
            compact: true,
            subtitle: '${_currentPeriodLabel(_scope, selMonth)} · ${_summaryActiveType == 'expense' ? '支出' : _summaryActiveType == 'income' ? '收入' : '汇总'}',
            center: null,
            padding: EdgeInsets.zero,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.black87),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('小提示'),
                      content: const Text(
                          '1) 顶部左右滑动可在“月/年/全部”切换\n2) 图表区域左右滑动可切换上一/下一周期\n3) 点击月份或年份可快速选择'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: CapsuleSwitcher<String>(
                selectedValue: _scope,
                options: [
                  CapsuleOption(
                    value: 'month',
                    label: '月',
                    showArrow: true,
                    onTap: () async {
                      final res = await showWheelDatePicker(
                        context,
                        initial: selMonth,
                        mode: WheelDatePickerMode.ym,
                        maxDate: DateTime.now(),
                      );
                      final picked =
                          res == null ? null : DateTime(res.year, res.month, 1);
                      if (picked != null) {
                        ref.read(selectedMonthProvider.notifier).state = picked;
                      }
                    },
                  ),
                  CapsuleOption(
                    value: 'year',
                    label: '年',
                    showArrow: true,
                    onTap: () async {
                      final res = await showWheelDatePicker(
                        context,
                        initial: selMonth,
                        mode: WheelDatePickerMode.y,
                        maxDate: DateTime.now(),
                      );
                      if (res != null) {
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(res.year, 1, 1);
                      }
                    },
                  ),
                  CapsuleOption(
                    value: 'all',
                    label: '全部',
                  ),
                ],
                onChanged: (value) => setState(() => _scope = value),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              key: ValueKey('summary_${_scope}_${selMonth.toString()}'),
              future: _buildFuture(ledgerId, start, end, seriesFuture),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data as List<dynamic>;

                // 处理分类数据 - 根据类型安全处理
                final dynamic rawCatData = list[0];
                List<({int? id, String name, double total, String? type})>
                    catDataWithType;
                double sum;

                // 固定汇总视角：数据应该有type字段
                final summaryData = rawCatData as List<
                    ({int? id, String name, double total, String type})>;
                catDataWithType = summaryData
                    .map((e) => (
                          id: e.id,
                          name: e.name,
                          total: e.total,
                          type: e.type as String?
                        ))
                    .toList();
                sum = catDataWithType.fold<double>(0, (a, b) => a + b.total);

                final seriesRaw = list[1];
                final txCount = list[2] as int;
                // 统一取数列的数值数组（固定汇总视角）
                List<double> valuesOnly() {
                  // 处理汇总视角的双数据结构，用支出数据判断是否为空
                  if (seriesRaw is List<
                      ({
                        DateTime day,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return seriesRaw.map((e) => e.expenseTotal).toList();
                  }
                  if (seriesRaw is List<
                      ({
                        DateTime month,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return seriesRaw.map((e) => e.expenseTotal).toList();
                  }
                  if (seriesRaw is List<
                      ({int year, double expenseTotal, double incomeTotal})>) {
                    return seriesRaw.map((e) => e.expenseTotal).toList();
                  }
                  return const <double>[];
                }

                final vals = valuesOnly();
                final allZero = vals.isEmpty || vals.every((v) => v == 0);
                if (txCount == 0 || (sum == 0 && allZero)) {
                  final headerDismissed = (ref
                              .watch(analyticsHeaderHintDismissedProvider)
                              .asData
                              ?.value ??
                          false) ||
                      _localHeaderDismissed;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      // 整个页面横滑切换时间周期
                      _handlePeriodSwipe(details);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const AppEmpty(
                          text: '暂无数据',
                          subtext: '可左右滑动切换时间周期，或用上方按钮切换时间范围',
                        ),
                        const SizedBox(height: 8),
                        if (!headerDismissed)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: BeeColors.secondaryText),
                              const SizedBox(width: 6),
                              Text('提示：顶部胶囊可切换 月/年/全部',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: BeeColors.secondaryText)),
                            ],
                          ),
                      ],
                    ),
                  );
                }

                // 注意：sum 非 0 或曲线存在非零值则继续渲染

                // 过滤数据：只显示到当前时间的数据（固定汇总视角）
                final filteredSeriesRaw = () {
                  if (seriesRaw is List<
                      ({
                        DateTime day,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return seriesRaw;
                  }
                  if (seriesRaw is List<
                      ({
                        DateTime month,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    final isCurrentYear = selMonth.year == now.year;
                    if (isCurrentYear) {
                      return seriesRaw
                          .where((e) => e.month.month <= now.month)
                          .toList();
                    }
                    return seriesRaw;
                  }
                  if (seriesRaw is List<
                      ({int year, double expenseTotal, double incomeTotal})>) {
                    return seriesRaw.where((e) => e.year <= now.year).toList();
                  }
                  return seriesRaw;
                }();

                // 转换为折线值数组 + x 轴标签（固定汇总视角）
                final values = () {
                  // 汇总视角：使用支出数据作为主线
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime day,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw
                        .map((e) => e.expenseTotal)
                        .toList();
                  }
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime month,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw
                        .map((e) => e.expenseTotal)
                        .toList();
                  }
                  if (filteredSeriesRaw is List<
                      ({int year, double expenseTotal, double incomeTotal})>) {
                    return filteredSeriesRaw
                        .map((e) => e.expenseTotal)
                        .toList();
                  }
                  return const <double>[];
                }();

                // 汇总视角的第二条线数据（收入）
                final secondaryValues = () {
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime day,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw.map((e) => e.incomeTotal).toList();
                  }
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime month,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw.map((e) => e.incomeTotal).toList();
                  }
                  if (filteredSeriesRaw is List<
                      ({int year, double expenseTotal, double incomeTotal})>) {
                    return filteredSeriesRaw.map((e) => e.incomeTotal).toList();
                  }
                  return const <double>[];
                }();

                final xLabels = () {
                  // 汇总视角
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime day,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw
                        .map((e) => e.day.day.toString())
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw is List<
                      ({
                        DateTime month,
                        double expenseTotal,
                        double incomeTotal
                      })>) {
                    return filteredSeriesRaw
                        .map((e) => '${e.month.month}月')
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw is List<
                      ({int year, double expenseTotal, double incomeTotal})>) {
                    return filteredSeriesRaw
                        .map((e) => e.year.toString())
                        .toList(growable: false);
                  }
                  return const <String>[];
                }();

                int? highlightIndex;
                if (_scope == 'month') {
                  final today = DateTime.now();
                  if (today.year == selMonth.year &&
                      today.month == selMonth.month) {
                    highlightIndex = today.day - 1; // 从 0 开始
                    if (highlightIndex >= 0 &&
                        highlightIndex < xLabels.length) {
                      xLabels[highlightIndex] = '今天';
                    }
                  }
                }

                // 提示是否已被持久化关闭
                final headerDismissed = (ref
                            .watch(analyticsHeaderHintDismissedProvider)
                            .asData
                            ?.value ??
                        false) ||
                    _localHeaderDismissed;
                final chartDismissed = (ref
                            .watch(analyticsChartHintDismissedProvider)
                            .asData
                            ?.value ??
                        false) ||
                    _localChartDismissed;

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    // 整个页面横滑切换时间周期
                    _handlePeriodSwipe(details);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AnalyticsSummary(
                        scope: _scope,
                        isExpense: false,
                        total: sum,
                        avg: _computeAverage(filteredSeriesRaw, _scope),
                        isSummary: true,
                        expenseTotal: _getExpenseTotal(catDataWithType),
                        incomeTotal: _getIncomeTotal(catDataWithType),
                        expenseAvg: _computeSummaryExpenseAverage(
                            filteredSeriesRaw, _scope),
                        incomeAvg: _computeSummaryIncomeAverage(
                            filteredSeriesRaw, _scope),
                        showExpense: _expenseLineActive,
                        showIncome: _incomeLineActive,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: LineChart(
                          values: values,
                          secondaryValues: secondaryValues,
                          secondaryColor: _incomeLineActive
                              ? Colors.green
                              : Colors.grey.shade400,
                          xLabels: xLabels,
                          highlightIndex: highlightIndex,
                          themeColor: _expenseLineActive
                              ? Colors.red
                              : Colors.grey.shade400,
                          onPrimaryLineTap: _toggleExpenseLine,
                          onSecondaryLineTap: _toggleIncomeLine,
                          // 使用统一图表令牌
                          lineWidth: AppChartTokens.lineWidth,
                          dotRadius: AppChartTokens.dotRadius,
                          cornerRadius: AppChartTokens.cornerRadius,
                          xLabelFontSize: AppChartTokens.xLabelFontSize,
                          yLabelFontSize: AppChartTokens.yLabelFontSize,
                          onSwipeLeft: () {
                            // 下一周期
                            if (_scope == 'all') return; // 全部不滑
                            final m = ref.read(selectedMonthProvider);
                            final now = DateTime.now();
                            if (_scope == 'month') {
                              var y = m.year;
                              var mon = m.month + 1;
                              if (mon > 12) {
                                mon = 1;
                                y++;
                              }
                              final cand = DateTime(y, mon, 1);
                              final lastAllowed =
                                  DateTime(now.year, now.month, 1);
                              if (!cand.isAfter(lastAllowed)) {
                                ref.read(selectedMonthProvider.notifier).state =
                                    cand;
                              }
                            } else if (_scope == 'year') {
                              final cand = DateTime(m.year + 1, 1, 1);
                              final lastAllowed = DateTime(now.year, 1, 1);
                              if (!cand.isAfter(lastAllowed)) {
                                ref.read(selectedMonthProvider.notifier).state =
                                    cand;
                              }
                            }
                          },
                          onSwipeRight: () {
                            // 上一周期
                            if (_scope == 'all') return;
                            final m = ref.read(selectedMonthProvider);
                            if (_scope == 'month') {
                              var y = m.year;
                              var mon = m.month - 1;
                              if (mon < 1) {
                                mon = 12;
                                y--;
                              }
                              ref.read(selectedMonthProvider.notifier).state =
                                  DateTime(y, mon, 1);
                            } else if (_scope == 'year') {
                              ref.read(selectedMonthProvider.notifier).state =
                                  DateTime(m.year - 1, 1, 1);
                            }
                          },
                          showHint: !chartDismissed,
                          hintText: '左右滑动切换周期',
                          onCloseHint: () async {
                            final setter =
                                ref.read(analyticsHintsSetterProvider);
                            await setter.dismissChart();
                            if (mounted) {
                              setState(() => _localChartDismissed = true);
                            }
                          },
                          whiteBg: true,
                          showGrid: false,
                          showDots: true,
                          annotate: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _summaryActiveType == 'expense'
                                ? '支出排行榜'
                                : _summaryActiveType == 'income'
                                    ? '收入排行榜'
                                    : '分类排行榜',
                            style: AppTextTokens.title(context),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BeeColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _currentPeriodLabel(_scope, selMonth),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: BeeColors.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!headerDismissed)
                            InkWell(
                              onTap: () async {
                                final setter =
                                    ref.read(analyticsHintsSetterProvider);
                                await setter.dismissHeader();
                                if (mounted) {
                                  setState(() => _localHeaderDismissed = true);
                                }
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.swipe,
                                      size: 14, color: BeeColors.secondaryText),
                                  const SizedBox(width: 4),
                                  Text('横滑切换',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: BeeColors.secondaryText)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.close,
                                      size: 14, color: BeeColors.hintText),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final item in catDataWithType.where((item) {
                        // 汇总视角下根据线条激活状态过滤分类
                        // 固定汇总视角，根据激活状态过滤
                        if (item.type == 'expense' && !_expenseLineActive) {
                          return false;
                        }
                        if (item.type == 'income' && !_incomeLineActive) {
                          return false;
                        }
                        return true;
                      }))
                        InkWell(
                          onTap: () => _openCategoryDetail(context, item.id,
                              item.name, start, end, 'summary'),
                          child: CategoryRankRow(
                            name: item.name,
                            value: item.total,
                            percent: sum == 0 ? 0 : item.total / sum,
                            color: _getCategoryColor(context, item.type),
                            isIncome: item.type == 'income' && _summaryActiveType == 'all',
                            isExpense: item.type == 'expense' && _summaryActiveType == 'all',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // 汇总视角的序列数据获取
  Future<dynamic> _getSummarySeriesFuture(String scope, int ledgerId,
      DateTime selMonth, DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);

    if (scope == 'month') {
      final expenseData = await repo.totalsByDay(
          ledgerId: ledgerId, type: 'expense', start: start, end: end);
      final incomeData = await repo.totalsByDay(
          ledgerId: ledgerId, type: 'income', start: start, end: end);
      return _combineDayData(expenseData, incomeData);
    } else if (scope == 'year') {
      final expenseData = await repo.totalsByMonth(
          ledgerId: ledgerId, type: 'expense', year: selMonth.year);
      final incomeData = await repo.totalsByMonth(
          ledgerId: ledgerId, type: 'income', year: selMonth.year);
      return _combineMonthData(expenseData, incomeData);
    } else {
      final expenseData =
          await repo.totalsByYearSeries(ledgerId: ledgerId, type: 'expense');
      final incomeData =
          await repo.totalsByYearSeries(ledgerId: ledgerId, type: 'income');
      return _combineYearData(expenseData, incomeData);
    }
  }

  // 汇总视角的分类数据获取
  Future<List<({int? id, String name, double total, String type})>>
      _getSummaryCategoriesFuture(
          int ledgerId, DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);

    final expenseCategories = await repo.totalsByCategory(
        ledgerId: ledgerId, type: 'expense', start: start, end: end);
    final incomeCategories = await repo.totalsByCategory(
        ledgerId: ledgerId, type: 'income', start: start, end: end);

    final List<({int? id, String name, double total, String type})> result = [];

    // 添加支出分类
    for (final cat in expenseCategories) {
      result
          .add((id: cat.id, name: cat.name, total: cat.total, type: 'expense'));
    }

    // 添加收入分类
    for (final cat in incomeCategories) {
      result
          .add((id: cat.id, name: cat.name, total: cat.total, type: 'income'));
    }

    // 按金额排序
    result.sort((a, b) => b.total.compareTo(a.total));

    return result;
  }

  // 汇总视角的交易数量获取
  Future<int> _getSummaryCountFuture(
      int ledgerId, DateTime start, DateTime end) async {
    final repo = ref.read(repositoryProvider);

    final expenseCount = await repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'expense', start: start, end: end);
    final incomeCount = await repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'income', start: start, end: end);

    return expenseCount + incomeCount;
  }

  // 合并日数据
  List<({DateTime day, double expenseTotal, double incomeTotal})>
      _combineDayData(
    List<({DateTime day, double total})> expenseData,
    List<({DateTime day, double total})> incomeData,
  ) {
    final Map<DateTime, double> expenseMap = {
      for (final item in expenseData) item.day: item.total
    };
    final Map<DateTime, double> incomeMap = {
      for (final item in incomeData) item.day: item.total
    };

    final allDays = {...expenseMap.keys, ...incomeMap.keys};

    return allDays
        .map((day) => (
              day: day,
              expenseTotal: expenseMap[day] ?? 0.0,
              incomeTotal: incomeMap[day] ?? 0.0,
            ))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  // 合并月数据
  List<({DateTime month, double expenseTotal, double incomeTotal})>
      _combineMonthData(
    List<({DateTime month, double total})> expenseData,
    List<({DateTime month, double total})> incomeData,
  ) {
    final Map<DateTime, double> expenseMap = {
      for (final item in expenseData) item.month: item.total
    };
    final Map<DateTime, double> incomeMap = {
      for (final item in incomeData) item.month: item.total
    };

    final allMonths = {...expenseMap.keys, ...incomeMap.keys};

    return allMonths
        .map((month) => (
              month: month,
              expenseTotal: expenseMap[month] ?? 0.0,
              incomeTotal: incomeMap[month] ?? 0.0,
            ))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  // 合并年数据
  List<({int year, double expenseTotal, double incomeTotal})> _combineYearData(
    List<({int year, double total})> expenseData,
    List<({int year, double total})> incomeData,
  ) {
    final Map<int, double> expenseMap = {
      for (final item in expenseData) item.year: item.total
    };
    final Map<int, double> incomeMap = {
      for (final item in incomeData) item.year: item.total
    };

    final allYears = {...expenseMap.keys, ...incomeMap.keys};

    return allYears
        .map((year) => (
              year: year,
              expenseTotal: expenseMap[year] ?? 0.0,
              incomeTotal: incomeMap[year] ?? 0.0,
            ))
        .toList()
      ..sort((a, b) => a.year.compareTo(b.year));
  }

  // 构建Future，确保数据类型一致（固定汇总视角）
  Future<List<dynamic>> _buildFuture(int ledgerId, DateTime start, DateTime end,
      Future<dynamic> seriesFuture) async {
    final categories = await _getSummaryCategoriesFuture(ledgerId, start, end);
    final series = await seriesFuture;
    final count = await _getSummaryCountFuture(ledgerId, start, end);
    return [categories, series, count];
  }

  // 获取汇总视角的支出总额
  double _getExpenseTotal(
      List<({int? id, String name, double total, String? type})>
          catDataWithType) {
    return catDataWithType
        .where((item) => item.type == 'expense')
        .fold<double>(0, (sum, item) => sum + item.total);
  }

  // 获取汇总视角的收入总额
  double _getIncomeTotal(
      List<({int? id, String name, double total, String? type})>
          catDataWithType) {
    return catDataWithType
        .where((item) => item.type == 'income')
        .fold<double>(0, (sum, item) => sum + item.total);
  }

  // 计算汇总视角的支出平均值
  double _computeSummaryExpenseAverage(dynamic seriesRaw, String scope) {
    final now = DateTime.now();

    if (seriesRaw
        is List<({DateTime day, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.expenseTotal);

      if (seriesRaw.isNotEmpty) {
        final firstDay = seriesRaw.first.day;
        final isCurrentMonth =
            firstDay.year == now.year && firstDay.month == now.month;

        if (isCurrentMonth) {
          return sum / now.day;
        } else {
          final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0).day;
          return sum / lastDay;
        }
      }
      return sum / seriesRaw.length;
    }

    if (seriesRaw
        is List<({DateTime month, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.expenseTotal);

      if (seriesRaw.isNotEmpty) {
        final firstMonth = seriesRaw.first.month;
        final isCurrentYear = firstMonth.year == now.year;

        if (isCurrentYear) {
          return sum / now.month;
        } else {
          return sum / 12;
        }
      }
      return sum / seriesRaw.length;
    }

    if (seriesRaw
        is List<({int year, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.expenseTotal);
      return sum / seriesRaw.length;
    }

    return 0;
  }

  // 计算汇总视角的收入平均值
  double _computeSummaryIncomeAverage(dynamic seriesRaw, String scope) {
    final now = DateTime.now();

    if (seriesRaw
        is List<({DateTime day, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.incomeTotal);

      if (seriesRaw.isNotEmpty) {
        final firstDay = seriesRaw.first.day;
        final isCurrentMonth =
            firstDay.year == now.year && firstDay.month == now.month;

        if (isCurrentMonth) {
          return sum / now.day;
        } else {
          final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0).day;
          return sum / lastDay;
        }
      }
      return sum / seriesRaw.length;
    }

    if (seriesRaw
        is List<({DateTime month, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.incomeTotal);

      if (seriesRaw.isNotEmpty) {
        final firstMonth = seriesRaw.first.month;
        final isCurrentYear = firstMonth.year == now.year;

        if (isCurrentYear) {
          return sum / now.month;
        } else {
          return sum / 12;
        }
      }
      return sum / seriesRaw.length;
    }

    if (seriesRaw
        is List<({int year, double expenseTotal, double incomeTotal})>) {
      if (seriesRaw.isEmpty) return 0;
      final sum = seriesRaw.fold<double>(0, (a, b) => a + b.incomeTotal);
      return sum / seriesRaw.length;
    }

    return 0;
  }
}

// 顶部类型下拉已移除

// 自定义选择器：月份（年+月）
// 旧的自定义年月选择器已移除，统一使用 showWheelDatePicker。

String _currentPeriodLabel(String scope, DateTime selMonth) {
  switch (scope) {
    case 'year':
      return '${selMonth.year}年';
    case 'all':
      return '全部年份';
    case 'month':
    default:
      return '${selMonth.year}-${selMonth.month.toString().padLeft(2, '0')}';
  }
}

double _computeAverage(dynamic seriesRaw, String scope) {
  final now = DateTime.now();

  if (seriesRaw is List<({DateTime day, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);

    // 月度视角：计算已经过去的天数
    if (seriesRaw.isNotEmpty) {
      final firstDay = seriesRaw.first.day;
      final isCurrentMonth =
          firstDay.year == now.year && firstDay.month == now.month;

      if (isCurrentMonth) {
        // 当前月份：使用今天的日期作为分母
        return sum / now.day;
      } else {
        // 历史月份：使用该月的总天数
        final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0).day;
        return sum / lastDay;
      }
    }
    return sum / seriesRaw.length;
  }

  if (seriesRaw is List<({DateTime month, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);

    // 年度视角：计算已经过去的月份
    if (seriesRaw.isNotEmpty) {
      final firstMonth = seriesRaw.first.month;
      final isCurrentYear = firstMonth.year == now.year;

      if (isCurrentYear) {
        // 当前年份：使用当前月份作为分母
        return sum / now.month;
      } else {
        // 历史年份：使用12个月
        return sum / 12;
      }
    }
    return sum / seriesRaw.length;
  }

  if (seriesRaw is List<({int year, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    // 全部视角：按实际年份数量计算
    return sum / seriesRaw.length;
  }

  return 0;
}

// 打开分类详情页面
void _openCategoryDetail(BuildContext context, int? categoryId,
    String categoryName, DateTime start, DateTime end, String type) {
  if (categoryId == null) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CategoryDetailPage(
        categoryId: categoryId,
        categoryName: categoryName,
      ),
    ),
  );
}
