import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/primary_header.dart';
import '../widgets/common.dart';
import '../styles/design.dart';
import '../providers.dart';
import '../widgets/category_icon.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _scope = 'month'; // month | year | all
  String _type = 'expense'; // expense | income
  bool _chartSwiped = false; // 吸收图表区域横滑，避免父级切换收入/支出
  bool _showHeaderHint = true; // 顶部“横滑切换”提示可关闭

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final selMonth = ref.watch(selectedMonthProvider);

    // 时间范围
    late DateTime start;
    late DateTime end;
    if (_scope == 'month') {
      start = DateTime(selMonth.year, selMonth.month, 1);
      end = DateTime(selMonth.year, selMonth.month + 1, 1);
    } else if (_scope == 'year') {
      start = DateTime(selMonth.year, 1, 1);
      end = DateTime(selMonth.year + 1, 1, 1);
    } else {
      final today = DateTime.now();
      start = DateTime(1970, 1, 1);
      end = DateTime(today.year, today.month, today.day)
          .add(const Duration(days: 1));
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
            title: '',
            center: null,
            padding: EdgeInsets.zero,
            content: const SizedBox.shrink(),
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _CapsuleSwitcher(
                value: _scope,
                onChanged: (s) => setState(() => _scope = s),
                onPickMonth: () async {
                  final picked = await _showMonthPicker(context, selMonth);
                  if (picked != null) {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(picked.year, picked.month, 1);
                  }
                },
                onPickYear: () async {
                  final picked = await _showYearPicker(context, selMonth);
                  if (picked != null) {
                    ref.read(selectedMonthProvider.notifier).state =
                        DateTime(picked.year, 1, 1);
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
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data as List<dynamic>;
                final catData =
                    (list[0] as List<({int? id, String name, double total})>);
                final seriesRaw = list[1];

                final sum = catData.fold<double>(0, (a, b) => a + b.total);

                // 转换为折线值数组 + x 轴标签
                final values = () {
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
                }();

                final xLabels = () {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    return seriesRaw
                        .map((e) => e.day.day.toString())
                        .toList(growable: false);
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    return seriesRaw
                        .map((e) => '${e.month.month}月')
                        .toList(growable: false);
                  }
                  if (seriesRaw is List<({int year, double total})>) {
                    return seriesRaw
                        .map((e) => e.year.toString())
                        .toList(growable: false);
                  }
                  return const <String>[];
                }();

                int? highlightIndex;
                if (_scope == 'month' &&
                    seriesRaw is List<({DateTime day, double total})>) {
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
                        avg: _computeAverage(seriesRaw, _scope),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: _LineChart(
                          values: values,
                          xLabels: xLabels,
                          highlightIndex: highlightIndex,
                          themeColor: Theme.of(context).colorScheme.primary,
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
                          showHint: false,
                          hintText: null,
                          onCloseHint: null,
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _currentPeriodLabel(_scope, selMonth),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ),
                          const Spacer(),
                          if (_showHeaderHint)
                            InkWell(
                              onTap: () =>
                                  setState(() => _showHeaderHint = false),
                              child: Row(
                                children: [
                                  const Icon(Icons.swipe,
                                      size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text('横滑切换',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: Colors.black54)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.close,
                                      size: 14, color: Colors.black45),
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
    final bg = Colors.black12.withOpacity(0.06);
    Widget seg({
      required String v,
      required String label,
      VoidCallback? onArrow,
    }) {
      final selected = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.transparent,
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
                        color: selected ? Colors.white : Colors.black87,
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
                      color: selected ? Colors.white : Colors.black87,
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
            ),
          ),
          if (showHint)
            Positioned(
              right: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.swipe, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        hintText ?? '左右滑动切换',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onCloseHint,
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.black45),
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
  _LinePainter({
    required this.values,
    required this.xLabels,
    required this.highlightIndex,
    required this.whiteBg,
    required this.showGrid,
    required this.showDots,
    required this.annotate,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..color = whiteBg ? Colors.white : Colors.black12.withOpacity(0.06);
    // 背景
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)), bgPaint);

    // 网格（可选）
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      const rows = 4;
      for (int i = 1; i <= rows; i++) {
        final y = size.height * i / (rows + 1);
        canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), gridPaint);
      }
    }

    if (values.isEmpty) return;

    // 数据归一化
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final avgV = values.reduce((a, b) => a + b) / values.length;
    final span = (maxV - minV).abs();
    final bottomPadding = 20.0;
    final topPadding = 12.0;
    double yFor(double v) {
      if (span == 0) return size.height / 2;
      final t = (v - minV) / span; // 0..1
      return topPadding + (1 - t) * (size.height - topPadding - bottomPadding);
    }

    final dx = (size.width - 24) / (values.length - 1).clamp(1, 999);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      points.add(Offset(12 + i * dx, yFor(values[i])));
    }

    // 平滑曲线（简易二次贝塞尔）
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final line = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;
    canvas.drawPath(path, line);

    if (showDots) {
      final dot = Paint()..color = themeColor;
      for (final p in points) {
        canvas.drawCircle(p, 2.5, dot);
      }
    }

    // 左侧Y轴线
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(8, topPadding),
        Offset(8, size.height - bottomPadding), axisPaint);

    // 最高线 + 平均线
    final maxY = yFor(maxV);
    final avgY = yFor(avgV);
    final maxLinePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1.2;
    final avgLinePaint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    // 虚线画平均线
    _drawDashedLine(
        canvas, Offset(8, avgY), Offset(size.width - 8, avgY), avgLinePaint,
        dashWidth: 6, gapWidth: 4);
    // 实线画最高线
    canvas.drawLine(
        Offset(8, maxY), Offset(size.width - 8, maxY), maxLinePaint);

    // 最高线标注数值（右侧）
    final maxLabel = TextPainter(
      text: TextSpan(
          text: _fmt(maxV),
          style: const TextStyle(fontSize: 10, color: Colors.black87)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    maxLabel.paint(canvas,
        Offset(size.width - 8 - maxLabel.width, maxY - maxLabel.height - 2));

    // 最高点标注（仅一个点）
    if (annotate) {
      final maxIndex = values.indexOf(maxV);
      if (maxIndex >= 0 && maxIndex < points.length) {
        final p = points[maxIndex];
        final tp = TextPainter(
          text: TextSpan(
              text: _fmt(maxV),
              style: const TextStyle(fontSize: 10, color: Colors.black87)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 80);
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 4));
      }
    }

    // 所有点数值标注
    if (annotate) {
      final textStyle = const TextStyle(fontSize: 9, color: Colors.black87);
      for (int i = 0; i < points.length; i++) {
        final tp = TextPainter(
          text: TextSpan(text: _fmt(values[i]), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);
        final pos = points[i] + const Offset(0, -10);
        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height));
      }
    }

    // X 轴标签
    if (xLabels.isNotEmpty) {
      final baseStyle = const TextStyle(fontSize: 10, color: Colors.black54);
      final hiStyle = const TextStyle(
          fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w600);
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
Future<DateTime?> _showMonthPicker(
    BuildContext context, DateTime initial) async {
  int year = initial.year;
  int month = initial.month;
  final years = List<int>.generate(101, (i) => 2000 + i);
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (ctx) {
      return SizedBox(
        height: 260,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      const Text('取消', style: TextStyle(color: Colors.black87)),
                ),
                const Text('选择月份',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, DateTime(year, month, 1)),
                  child:
                      const Text('完成', style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: years.indexOf(year)),
                      itemExtent: 36,
                      onSelectedItemChanged: (i) => year = years[i],
                      children: [
                        for (final y in years) Center(child: Text('$y年'))
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: month - 1),
                      itemExtent: 36,
                      onSelectedItemChanged: (i) => month = i + 1,
                      children: [
                        for (int m = 1; m <= 12; m++) Center(child: Text('$m月'))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// 自定义选择器：年份
Future<DateTime?> _showYearPicker(
    BuildContext context, DateTime initial) async {
  int year = initial.year;
  final years = List<int>.generate(101, (i) => 2000 + i);
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (ctx) {
      return SizedBox(
        height: 240,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      const Text('取消', style: TextStyle(color: Colors.black87)),
                ),
                const Text('选择年份',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, DateTime(year, 1, 1)),
                  child:
                      const Text('完成', style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                    initialItem: years.indexOf(year)),
                itemExtent: 36,
                onSelectedItemChanged: (i) => year = years[i],
                children: [for (final y in years) Center(child: Text('$y年'))],
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
    final grey = Colors.black54;
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

void _openCategoryDetail(BuildContext context, int? categoryId, String name,
    DateTime start, DateTime end, String type) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _CategoryDetailPage(
      categoryId: categoryId,
      categoryName: name,
      start: start,
      end: end,
      type: type,
    ),
  ));
}

class _CategoryDetailPage extends ConsumerWidget {
  final int? categoryId;
  final String categoryName;
  final DateTime start;
  final DateTime end;
  final String type;
  const _CategoryDetailPage({
    required this.categoryId,
    required this.categoryName,
    required this.start,
    required this.end,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: categoryName,
            showBack: true,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.list_alt, color: Colors.black87),
              )
            ],
          ),
          Expanded(
            child: StreamBuilder(
              stream: repo.transactionsForCategoryInRange(
                  ledgerId: ledgerId,
                  start: start,
                  end: end,
                  categoryId: categoryId,
                  type: type),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const Center(child: Text('暂无明细'));
                }
                if (list.isEmpty) return const AppEmpty();
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => AppDivider.thin(),
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final t = item.t;
                    final c = item.category;
                    final title =
                        '${c?.name ?? '未分类'} · ${_fmtDate(t.happenedAt.toLocal())}';
                    return TransactionListItem(
                      icon: iconForCategory(c?.name ?? '未分类'),
                      title: title,
                      amount: t.amount,
                      isExpense: t.type == 'expense',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
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
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black12.withOpacity(0.06),
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
                            ?.copyWith(color: Colors.black45)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: color.withOpacity(0.15)),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0, 1),
                        child:
                            Container(height: 6, color: color.withOpacity(0.9)),
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
  if (seriesRaw is List<({DateTime day, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length;
  }
  if (seriesRaw is List<({DateTime month, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length;
  }
  if (seriesRaw is List<({int year, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length;
  }
  return 0;
}
