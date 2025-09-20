import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// wheel_date_picker exported via ui barrel
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../providers.dart';
import '../widgets/category_icon.dart';
import '../styles/colors.dart';
import '../widgets/ui/ui.dart';
import 'category_detail_page.dart';

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
              child: _CapsuleSwitcher(
                value: _scope,
                onChanged: (s) => setState(() => _scope = s),
                onPickMonth: () async {
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
                onPickYear: () async {
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
                      _TopTexts(
                        scope: _scope,
                        isExpense: _type == 'expense',
                        total: sum,
                        avg: _computeAverage(filteredSeriesRaw, _scope),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: _LineChart(
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
                          child: _RankRow(
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

class _CapsuleSwitcher extends StatelessWidget {
  final String value; // month | year | all
  final ValueChanged<String> onChanged;
  final VoidCallback? onPickMonth;
  final VoidCallback? onPickYear;
  const _CapsuleSwitcher({
    required this.value,
    required this.onChanged,
    this.onPickMonth,
    this.onPickYear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = BeeColors.divider;
    Widget seg({
      required String v,
      required String label,
      VoidCallback? onArrow,
    }) {
      final selected = value == v;
      final selectedBg = Colors.black;
      final selectedFg = Colors.white;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected ? selectedFg : BeeColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (onArrow != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onArrow,
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: selected ? selectedFg : BeeColors.primaryText,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          seg(v: 'month', label: '月', onArrow: onPickMonth),
          const SizedBox(width: 4),
          seg(v: 'year', label: '年', onArrow: onPickYear),
          const SizedBox(width: 4),
          seg(v: 'all', label: '全部'),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> xLabels;
  final int? highlightIndex;
  final VoidCallback onSwipeLeft; // 下一周期
  final VoidCallback onSwipeRight; // 上一周期
  final bool showHint;
  final String? hintText;
  final VoidCallback? onCloseHint;
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final Color themeColor;
  // 令牌化参数
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;
  const _LineChart({
    required this.values,
    required this.xLabels,
    required this.highlightIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.showHint,
    this.hintText,
    this.onCloseHint,
    this.whiteBg = true,
    this.showGrid = true,
    this.showDots = true,
    this.annotate = true,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0) {
          onSwipeLeft();
        } else if (v > 0) {
          onSwipeRight();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LinePainter(
              values: values,
              xLabels: xLabels,
              highlightIndex: highlightIndex,
              whiteBg: whiteBg,
              showGrid: showGrid,
              showDots: showDots,
              annotate: annotate,
              themeColor: themeColor,
              lineWidth: lineWidth,
              dotRadius: dotRadius,
              cornerRadius: cornerRadius,
              xLabelFontSize: xLabelFontSize,
              yLabelFontSize: yLabelFontSize,
            ),
          ),
          if (showHint)
            Positioned(
              right: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BeeColors.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.swipe,
                          size: 14, color: BeeColors.secondaryText),
                      const SizedBox(width: 4),
                      Text(
                        hintText ?? '左右滑动切换',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: BeeColors.secondaryText),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onCloseHint,
                        child: Icon(Icons.close,
                            size: 14, color: BeeColors.hintText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<String> xLabels;
  final int? highlightIndex;
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final Color themeColor;
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;
  _LinePainter({
    required this.values,
    required this.xLabels,
    required this.highlightIndex,
    required this.whiteBg,
    required this.showGrid,
    required this.showDots,
    required this.annotate,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = whiteBg ? Colors.white : BeeColors.divider;
    // 背景
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)), bgPaint);

    // 网格（可选）
    if (showGrid) {
      final gridPaint = Paint()
        ..color = BeeColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      const rows = 4;
      for (int i = 1; i <= rows; i++) {
        final y = size.height * i / (rows + 1);
        canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
      }
    }

    if (values.isEmpty) return;

    // 数据归一化 - 包含所有值（包括0）用于正确的Y轴缩放
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);

    // 计算非零值的平均值，用于平均线绘制
    final nonZeroVals = values.where((v) => v != 0).toList();
    final avgV = nonZeroVals.isEmpty
        ? 0.0
        : nonZeroVals.reduce((a, b) => a + b) / nonZeroVals.length;

    final span = (maxV - minV).abs();
    final bottomPadding = 20.0;
    final topPadding = 12.0;
    double yFor(double v) {
      if (span == 0) return size.height / 2;
      final t = (v - minV) / span; // 0..1
      return topPadding + (1 - t) * (size.height - topPadding - bottomPadding);
    }

    final dx = (size.width - 24) / (values.length - 1).clamp(1, 999);
    Offset pointFor(int i) => Offset(12 + i * dx, yFor(values[i]));

    // 为所有点生成坐标，包括零值点，确保线条连续
    final allPoints = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      allPoints.add(pointFor(i));
    }

    // 收集非零点的索引，用于绘制圆点和标注
    final nzIndices = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] != 0) nzIndices.add(i);
    }

    final line = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true;

    // 绘制连续的折线，包括所有点（包括零值点）
    if (allPoints.length >= 2) {
      final path = Path()..moveTo(allPoints.first.dx, allPoints.first.dy);
      for (int i = 1; i < allPoints.length; i++) {
        path.lineTo(allPoints[i].dx, allPoints[i].dy);
      }
      canvas.drawPath(path, line);
    }

    if (showDots) {
      final dot = Paint()..color = themeColor;
      // 只在非零值点绘制圆点
      for (final i in nzIndices) {
        canvas.drawCircle(allPoints[i], dotRadius, dot);
      }
    }

    // 左侧Y轴线
    final axisPaint = Paint()
      ..color = BeeColors.divider
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(8, topPadding),
        Offset(8, size.height - bottomPadding), axisPaint);

    // 不显示“最高线”和最高金额，仅绘制平均线（虚线）
    final avgY = yFor(avgV);
    final avgLinePaint = Paint()
      ..color = BeeColors.secondaryText.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
        canvas, Offset(8, avgY), Offset(size.width - 8, avgY), avgLinePaint,
        dashWidth: 6, gapWidth: 4);

    // 所有非零点数值标注
    if (annotate) {
      final textStyle =
          TextStyle(fontSize: yLabelFontSize - 1, color: BeeColors.primaryText);
      for (final i in nzIndices) {
        final tp = TextPainter(
          text: TextSpan(text: _fmt(values[i]), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final pos = allPoints[i] + const Offset(0, -10);
        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height));
      }
    }

    // X 轴标签（保持原始标签与索引）
    if (xLabels.isNotEmpty) {
      final baseStyle =
          TextStyle(fontSize: xLabelFontSize, color: BeeColors.secondaryText);
      final hiStyle = TextStyle(
          fontSize: xLabelFontSize,
          color: BeeColors.primaryText,
          fontWeight: FontWeight.w600);
      final n = xLabels.length;
      int step = (n / 8).ceil();
      if (step < 1) step = 1;
      for (int i = 0; i < n; i += step) {
        final lbl = xLabels[i];
        final tp = TextPainter(
          text: TextSpan(
              text: lbl,
              style: (highlightIndex != null && i == highlightIndex)
                  ? hiStyle
                  : baseStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final dxi = (i / (n - 1).clamp(1, 999)) * (size.width - 24) + 12;
        tp.paint(
            canvas, Offset(dxi - tp.width / 2, size.height - tp.height - 2));
      }
    }
  }

  String _fmt(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}w';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.whiteBg != whiteBg ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.annotate != annotate;
  }
}

void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint,
    {double dashWidth = 5, double gapWidth = 3}) {
  final total = (p2 - p1).distance;
  final dir = (p2 - p1) / total;
  double drawn = 0;
  while (drawn < total) {
    final start = p1 + dir * drawn;
    final end = p1 + dir * (drawn + dashWidth).clamp(0, total);
    canvas.drawLine(start, end, paint);
    drawn += dashWidth + gapWidth;
  }
}

// 自定义选择器：月份（年+月）
// 旧的自定义年月选择器已移除，统一使用 showWheelDatePicker。

class _TopTexts extends StatelessWidget {
  final String scope; // month/year/all
  final bool isExpense;
  final double total;
  final double avg;
  const _TopTexts(
      {required this.scope,
      required this.isExpense,
      required this.total,
      required this.avg});

  @override
  Widget build(BuildContext context) {
    final grey = BeeColors.secondaryText;
    final titleWord = isExpense ? '支出' : '收入';
    String avgLabel;
    switch (scope) {
      case 'year':
        avgLabel = '月均';
        break;
      case 'all':
        avgLabel = '平均值';
        break;
      case 'month':
      default:
        avgLabel = '日均';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('总$titleWord： ',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: grey)),
            Text(total.toStringAsFixed(2),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: grey, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('$avgLabel： ',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: grey)),
            Text(avg.toStringAsFixed(2),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: grey)),
          ],
        ),
        const SizedBox(height: 8),
        AppDivider.thin(),
      ],
    );
  }
}

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

class _RankRow extends StatelessWidget {
  final String name;
  final double value;
  final double percent; // 0..1
  final Color color;
  const _RankRow(
      {required this.name,
      required this.value,
      required this.percent,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconForCategory(name), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 8),
                    AmountText(value: value, signed: false, decimals: 0),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${(percent * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: BeeColors.hintText)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 6, color: color.withValues(alpha: 0.15)),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0, 1),
                        child: Container(
                            height: 6, color: color.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
