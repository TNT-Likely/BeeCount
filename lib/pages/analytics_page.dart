import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'analytics2_page.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _scope = 'month'; // month | year | all
  String _type = 'expense'; // expense | income
  bool _chartSwiped = false; // 吸收图表区域横滑，避免父级切换收入/支出
  bool _localHeaderDismissed = false; // 本地快速隐藏，实际持久化在 provider 中
  bool _localChartDismissed = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
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

    // 按视角获取序列
    final Future<dynamic> seriesFuture = _scope == 'month'
        ? repo.totalsByDay(
            ledgerId: ledgerId, type: _type, start: start, end: end)
        : _scope == 'year'
            ? repo.totalsByMonth(
                ledgerId: ledgerId, type: _type, year: selMonth.year)
            : repo.totalsByYearSeries(ledgerId: ledgerId, type: _type);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '图表分析',
            leadingIcon: Icons.bar_chart_outlined,
            leadingPlain: true,
            compact: true,
            subtitle:
                '${_currentPeriodLabel(_scope, selMonth)} · ${_type == 'expense' ? '支出' : '收入'}',
            center: null,
            padding: EdgeInsets.zero,
            actions: [
              if (kDebugMode)
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Colors.black87),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const Analytics2Page(),
                      ),
                    );
                  },
                ),
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
              future: Future.wait([
                repo.totalsByCategory(
                    ledgerId: ledgerId, type: _type, start: start, end: end),
                seriesFuture,
                repo.countByTypeInRange(
                    ledgerId: ledgerId, type: _type, start: start, end: end),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data as List<dynamic>;
                final catData =
                    (list[0] as List<({int? id, String name, double total})>);
                final seriesRaw = list[1];
                final txCount = list[2] as int;
                final sum = catData.fold<double>(0, (a, b) => a + b.total);
                // 统一取数列的数值数组
                List<double> valuesOnly() {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  if (seriesRaw is List<({int year, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
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
                    onHorizontalDragEnd: (_) {
                      setState(() =>
                          _type = _type == 'expense' ? 'income' : 'expense');
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const AppEmpty(
                          text: '暂无数据',
                          subtext: '可左右滑动切换 收入/支出，或用上方周期切换',
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz),
                            label:
                                Text('切换到${_type == "expense" ? "收入" : "支出"}'),
                            onPressed: () => setState(() => _type =
                                _type == 'expense' ? 'income' : 'expense'),
                          ),
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

                // 过滤数据：只显示到当前时间的数据
                final filteredSeriesRaw = () {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    // 天数据：已经通过时间范围过滤了
                    return seriesRaw;
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    // 月数据：过滤到当前月份
                    final isCurrentYear = selMonth.year == now.year;
                    if (isCurrentYear) {
                      return seriesRaw
                          .where((e) => e.month.month <= now.month)
                          .toList();
                    }
                    return seriesRaw;
                  }
                  if (seriesRaw is List<({int year, double total})>) {
                    // 年数据：过滤到当前年份
                    return seriesRaw.where((e) => e.year <= now.year).toList();
                  }
                  return seriesRaw;
                }();

                // 转换为折线值数组 + x 轴标签
                final values = () {
                  if (filteredSeriesRaw
                      is List<({DateTime day, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  if (filteredSeriesRaw
                      is List<({DateTime month, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  if (filteredSeriesRaw is List<({int year, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  return const <double>[];
                }();

                final xLabels = () {
                  if (filteredSeriesRaw
                      is List<({DateTime day, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => e.day.day.toString())
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw
                      is List<({DateTime month, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => '${e.month.month}月')
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw is List<({int year, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => e.year.toString())
                        .toList(growable: false);
                  }
                  return const <String>[];
                }();

                int? highlightIndex;
                if (_scope == 'month' &&
                    filteredSeriesRaw is List<({DateTime day, double total})>) {
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
                  onHorizontalDragEnd: (_) {
                    if (_chartSwiped) {
                      setState(() => _chartSwiped = false);
                      return;
                    }
                    setState(() =>
                        _type = _type == 'expense' ? 'income' : 'expense');
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AnalyticsSummary(
                        scope: _scope,
                        isExpense: _type == 'expense',
                        total: sum,
                        avg: _computeAverage(filteredSeriesRaw, _scope),
                        expenseColor: Theme.of(context).colorScheme.primary,
                        incomeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: LineChart(
                          values: values,
                          xLabels: xLabels,
                          highlightIndex: highlightIndex,
                          themeColor: Theme.of(context).colorScheme.primary,
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
                            setState(() => _chartSwiped = true);
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
                            setState(() => _chartSwiped = true);
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
                            _type == 'expense' ? '支出排行榜' : '收入排行榜',
                            style: AppTextTokens.title(context),
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
                      for (final item in catData)
                        InkWell(
                          onTap: () => _openCategoryDetail(
                              context, item.id, item.name, start, end, _type),
                          child: CategoryRankRow(
                            name: item.name,
                            value: item.total,
                            percent: sum == 0 ? 0 : item.total / sum,
                            color: Theme.of(context).colorScheme.primary,
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
