import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/primary_header.dart';
import '../providers.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _scope = 'month'; // week/month/year
  String _type = 'expense'; // expense/income，左右滑切换
  double _pieLabelThreshold = 0.05; // 饼图标签阈值，可配置

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    DateTime start, end;
    if (_scope == 'week') {
      final firstOfMonth = DateTime(month.year, month.month, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final today = DateTime.now();
      final weekStartCandidate = today.subtract(const Duration(days: 6));
      start = weekStartCandidate.isBefore(firstOfMonth)
          ? firstOfMonth
          : DateTime(weekStartCandidate.year, weekStartCandidate.month,
              weekStartCandidate.day);
      end = today.isAfter(nextMonth)
          ? nextMonth
          : DateTime(today.year, today.month, today.day).add(
              const Duration(days: 1),
            );
    } else if (_scope == 'month') {
      start = DateTime(month.year, month.month, 1);
      end = DateTime(month.year, month.month + 1, 1);
    } else {
      start = DateTime(month.year, 1, 1);
      end = DateTime(month.year + 1, 1, 1);
    }

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '图表',
            bottom: _ScopeSwitcher(
              scope: _scope,
              onScope: (s) => setState(() => _scope = s),
              type: _type,
              onSwipeType: (t) => setState(() => _type = t),
              labelThreshold: _pieLabelThreshold,
              onChangeThreshold: (v) => setState(() => _pieLabelThreshold = v),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                repo.totalsByCategory(
                    ledgerId: ledgerId, type: _type, start: start, end: end),
                if (_scope == 'year')
                  repo.totalsByMonth(
                      ledgerId: ledgerId, type: _type, year: month.year)
                else
                  repo.totalsByDay(
                      ledgerId: ledgerId, type: _type, start: start, end: end),
                repo.totalsInRange(ledgerId: ledgerId, start: start, end: end),
              ]),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data as List<dynamic>;
                final catData =
                    (list[0] as List<({String name, double total})>);
                final seriesRaw = list[1];
                final (rangeIncome, rangeExpense) =
                    (list[2] as (double, double));

                // 标准化序列为 double 列表
                List<double> series;
                List<String> xLabels;
                if (_scope == 'year') {
                  final m = seriesRaw as List<({DateTime month, double total})>;
                  series = m.map((e) => e.total).toList();
                  xLabels = List.generate(12, (i) => '${i + 1}月');
                } else {
                  final d = seriesRaw as List<({DateTime day, double total})>;
                  series = d.map((e) => e.total).toList();
                  xLabels = d
                      .map((e) => '${e.day.month}/${e.day.day}')
                      .toList(growable: false);
                }

                final sum = catData.fold<double>(0, (a, b) => a + b.total);
                final balance = rangeIncome - rangeExpense;

                return GestureDetector(
                  onHorizontalDragEnd: (_) => setState(
                      () => _type = _type == 'expense' ? 'income' : 'expense'),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryCards(
                        income: rangeIncome,
                        expense: rangeExpense,
                        balance: balance,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: _LineChart(series: series, labels: xLabels),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: _PieChart(
                          data: catData,
                          total: sum,
                          labelThreshold: _pieLabelThreshold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('图例 / 排行',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final item in catData)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: pieColorFor(item.name),
                          ),
                          title: Text(item.name),
                          trailing: Text(
                              '${sum <= 0 ? '0%' : ((item.total / sum) * 100).toStringAsFixed(0)}%  ${item.total.toStringAsFixed(2)}'),
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

class _ScopeSwitcher extends StatelessWidget {
  final String scope;
  final ValueChanged<String> onScope;
  final String type;
  final ValueChanged<String> onSwipeType;
  final double labelThreshold;
  final ValueChanged<double> onChangeThreshold;
  const _ScopeSwitcher({
    required this.scope,
    required this.onScope,
    required this.type,
    required this.onSwipeType,
    required this.labelThreshold,
    required this.onChangeThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('周视角')),
              ButtonSegment(value: 'month', label: Text('月视角')),
              ButtonSegment(value: 'year', label: Text('年视角')),
            ],
            selected: {scope},
            onSelectionChanged: (s) => onScope(s.first),
          ),
          const Spacer(),
          Text(type == 'expense' ? '支出' : '收入',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          const Icon(Icons.swipe, size: 16),
          const SizedBox(width: 4),
          const Text('横滑切换'),
          const SizedBox(width: 12),
          PopupMenuButton<double>(
            tooltip: '饼图标签阈值',
            onSelected: onChangeThreshold,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 0.03, child: Text('标签≥3%')),
              PopupMenuItem(value: 0.05, child: Text('标签≥5%')),
              PopupMenuItem(value: 0.08, child: Text('标签≥8%')),
            ],
            child: Row(
              children: [
                const Icon(Icons.percent, size: 16),
                const SizedBox(width: 4),
                Text('${(labelThreshold * 100).toStringAsFixed(0)}%'),
              ],
            ),
          )
        ],
      ),
    );
  }
}

Color pieColorFor(String name) => _PiePainter.colorFor(name);

class _PieChart extends StatelessWidget {
  final List<({String name, double total})> data;
  final double total;
  final double labelThreshold;
  const _PieChart({
    required this.data,
    required this.total,
    this.labelThreshold = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PiePainter(
        data: data,
        total: total,
        labelThreshold: labelThreshold,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(total.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleLarge),
            Text('总计', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<({String name, double total})> data;
  final double total;
  final double labelThreshold;
  _PiePainter({
    required this.data,
    required this.total,
    this.labelThreshold = 0.05,
  });

  static const List<Color> _palette = [
    Color(0xFF5B8FF9),
    Color(0xFF61DDAA),
    Color(0xFFFFC46B),
    Color(0xFFFF6F6F),
    Color(0xFF945FB9),
    Color(0xFF5AD8A6),
    Color(0xFF5D7092),
    Color(0xFFF6BD16),
    Color(0xFF6DC8EC),
    Color(0xFF1E9493),
    Color(0xFFE8684A),
  ];

  static Color colorFor(String name) {
    // 稳定映射：根据名称哈希到调色板索引
    int hash = 0;
    for (var code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide * 0.45;
    final paint = Paint()..style = PaintingStyle.fill;
    double start = -90 * 3.1415926 / 180.0;
    if (total <= 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawCircle(center, radius, paint);
      return;
    }
    for (int i = 0; i < data.length; i++) {
      final v = data[i];
      final pct = v.total / total;
      final sweep = pct * 2 * 3.1415926;
      paint.color = colorFor(v.name);
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(arcRect, start, sweep, true, paint);

      // 标签（>= 阈值 才绘制，避免拥挤）：名称 + 百分比
      if (pct >= labelThreshold) {
        final mid = start + sweep / 2;
        final labelPos = center +
            Offset(
              radius * 0.66 * math.cos(mid),
              radius * 0.66 * math.sin(mid),
            );
        final percentText =
            '${(pct * 100).toStringAsFixed(pct >= 0.1 ? 0 : 1)}%';
        final textSpan = TextSpan(
          text: '${v.name} $percentText',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: radius);

        // 绘制一个浅色背景块提高可读性
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: labelPos,
            width: tp.width + 8,
            height: tp.height + 4,
          ),
          const Radius.circular(6),
        );
        final bgPaint = Paint()..color = Colors.white.withOpacity(0.85);
        canvas.drawRRect(bgRect, bgPaint);
        tp.paint(
          canvas,
          Offset(
            labelPos.dx - tp.width / 2,
            labelPos.dy - tp.height / 2,
          ),
        );
      }

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.labelThreshold != labelThreshold;
  }
}

class _SummaryCards extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  const _SummaryCards(
      {required this.income, required this.expense, required this.balance});

  @override
  Widget build(BuildContext context) {
    Widget card(String title, double value, Color color) => Expanded(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(value.toStringAsFixed(2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        card('收入', income, Colors.teal),
        card('支出', expense, Colors.orange),
        Expanded(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('结余',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(balance.toStringAsFixed(2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: balance >= 0 ? Colors.teal : Colors.redAccent,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<double> series;
  final List<String> labels;
  const _LineChart({required this.series, required this.labels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(series: series, labels: labels),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> series;
  final List<String> labels;
  _LineChartPainter({required this.series, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final padding = const EdgeInsets.fromLTRB(8, 8, 8, 20);
    final chart = Rect.fromLTWH(
        rect.left + padding.left,
        rect.top + padding.top,
        rect.width - padding.horizontal,
        rect.height - padding.vertical);

    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    // X/Y axis baseline
    canvas.drawLine(Offset(chart.left, chart.bottom),
        Offset(chart.right, chart.bottom), axisPaint);
    canvas.drawLine(Offset(chart.left, chart.top),
        Offset(chart.left, chart.bottom), axisPaint);

    if (series.isEmpty) return;
    final maxVal = series.fold<double>(0, (a, b) => a > b ? a : b);
    final minVal = 0.0;
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final stepX = chart.width / (series.length - 1).clamp(1, double.infinity);
    final path = Path();
    final pointPaint = Paint()..color = const Color(0xFF5B8FF9);

    for (int i = 0; i < series.length; i++) {
      final x = chart.left + stepX * i;
      final y = chart.bottom - (series[i] - minVal) / range * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF5B8FF9);
    canvas.drawPath(path, linePaint);

    // points
    for (int i = 0; i < series.length; i++) {
      final x = chart.left + stepX * i;
      final y = chart.bottom - (series[i] - minVal) / range * chart.height;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    // x labels (sparse if too many)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final every = (labels.length / 6).ceil().clamp(1, 9999);
    for (int i = 0; i < labels.length; i += every) {
      final x = chart.left + stepX * i;
      tp.text = TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 10, color: Colors.black54));
      tp.layout(maxWidth: 60);
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.labels != labels;
  }
}
