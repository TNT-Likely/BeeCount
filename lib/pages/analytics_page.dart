import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/primary_header.dart';
import '../providers.dart';
import '../widgets/category_icon.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _scope = 'month'; // month/year/all
  String _type = 'expense'; // expense/income，左右滑切换
  bool _chartSwiped = false; // 阻止父级横滑在图表区域触发

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);

    DateTime start, end;
    if (_scope == 'month') {
      start = DateTime(month.year, month.month, 1);
      end = DateTime(month.year, month.month + 1, 1);
    } else if (_scope == 'year') {
      start = DateTime(month.year, 1, 1);
      end = DateTime(month.year + 1, 1, 1);
    } else {
      final today = DateTime.now();
      start = DateTime(1970, 1, 1);
      end = DateTime(today.year, today.month, today.day)
          .add(const Duration(days: 1));
    }

    final Future<dynamic> seriesFuture = _scope == 'year'
        ? repo.totalsByMonth(ledgerId: ledgerId, type: _type, year: month.year)
        : _scope == 'month'
            ? repo.totalsByDay(
                ledgerId: ledgerId, type: _type, start: start, end: end)
            : Future.value(const <({DateTime day, double total})>[]);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: _type == 'expense' ? '支出 ▼' : '收入 ▼',
            bottom: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _CapsuleSwitcher(
                value: _scope,
                onChanged: (s) => setState(() => _scope = s),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                repo.totalsByCategory(
                    ledgerId: ledgerId, type: _type, start: start, end: end),
                seriesFuture,
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

                final sum = catData.fold<double>(0, (a, b) => a + b.total);
                final List<double> lineValues = () {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  return const <double>[];
                }();

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
                        height: 220,
                        child: _LineChart(
                          values: lineValues,
                          onScopeSwipe: () {
                            setState(() {
                              if (_scope == 'year') {
                                _scope = 'month';
                              } else if (_scope == 'month') {
                                _scope = 'year';
                              }
                              _chartSwiped = true;
                            });
                          },
                          showHint: _scope != 'all',
                          isYear: _scope == 'year',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_type == 'expense' ? '支出排行榜' : '收入排行榜',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final item in catData)
                        _RankRow(
                          name: item.name,
                          value: item.total,
                          percent: sum == 0 ? 0 : item.total / sum,
                          color: Theme.of(context).colorScheme.primary,
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

// 颜色方案（可用于折线或图例）
Color pieColorFor(String name) => const Color(0xFF5B8FF9);

// 简易折线图实现
class _LineChart extends StatelessWidget {
  final List<double> values;
  final VoidCallback onScopeSwipe;
  final bool showHint;
  final bool isYear;
  const _LineChart({
    required this.values,
    required this.onScopeSwipe,
    required this.showHint,
    required this.isYear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (_) => onScopeSwipe(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LinePainter(values: values),
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
                        isYear ? '左右滑动切换至 月' : '左右滑动切换至 年',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.black54),
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
  _LinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()..color = Colors.black12.withOpacity(0.06);
    final axis = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    // 背景
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      bg,
    );

    // 坐标轴底部线
    final bottom = size.height - 16;
    canvas.drawLine(Offset(8, bottom), Offset(size.width - 8, bottom), axis);

    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV).abs();
    y(double v) {
      if (span == 0) return bottom - 40; // 平线
      final t = (v - minV) / span;
      return 12 + (1 - t) * (bottom - 24);
    }

    final dx = (size.width - 24) / (values.length - 1).clamp(1, 999);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final px = 12 + i * dx;
      final py = y(values[i]);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    final line = Paint()
      ..color = const Color(0xFF5B8FF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;
    canvas.drawPath(path, line);

    // 端点
    final dot = Paint()..color = const Color(0xFF5B8FF9);
    for (int i = 0; i < values.length; i++) {
      final px = 12 + i * dx;
      final py = y(values[i]);
      canvas.drawCircle(Offset(px, py), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _TopTexts extends StatelessWidget {
  final String scope; // week/month/year
  final bool isExpense;
  final double total;
  final double avg;
  const _TopTexts({
    required this.scope,
    required this.isExpense,
    required this.total,
    required this.avg,
  });

  @override
  Widget build(BuildContext context) {
    final grey = Colors.black54;
    final titleWord = isExpense ? '支出' : '收入';
    final primaryColor = Theme.of(context).colorScheme.primary;
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: primaryColor, fontWeight: FontWeight.w600)),
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
        Divider(height: 1, color: Colors.black12.withOpacity(0.2)),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final String name;
  final double value;
  final double percent; // 0..1
  final Color color;
  const _RankRow({
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
  });

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
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodyMedium),
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
                      Container(
                        height: 6,
                        color: color.withOpacity(0.15),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0, 1),
                        child: Container(
                          height: 6,
                          color: color.withOpacity(0.9),
                        ),
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
  return 0;
}

// 线图已替换为饼图布局，上面保留的平均值使用序列计算

// 胶囊分段（月/年/全部）
class _CapsuleSwitcher extends StatelessWidget {
  final String value; // 'month' | 'year' | 'all'
  final ValueChanged<String> onChanged;
  const _CapsuleSwitcher({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black12.withOpacity(0.06);
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    Widget seg(String v, String label, {bool last = false}) {
      final selected = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: textStyle?.copyWith(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          seg('month', '月'),
          const SizedBox(width: 4),
          seg('year', '年'),
          const SizedBox(width: 4),
          seg('all', '全部'),
        ],
      ),
    );
  }
}
