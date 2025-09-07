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
  String _scope = 'month'; // week/month/year
  String _type = 'expense'; // expense/income，左右滑切换
  final double _pieLabelThreshold = 0.05; // 固定阈值，贴合截图简洁度

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
            title: _type == 'expense' ? '支出 ▼' : '收入 ▼',
            bottom: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CapsuleSwitcher(
                    value: _scope,
                    onChanged: (s) => setState(() => _scope = s),
                  ),
                  const SizedBox(height: 8),
                  const _WeekStrip(),
                ],
              ),
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
                // 保留 totalsInRange 供后续卡片扩展需要，当前布局不直接展示
                // final (rangeIncome, rangeExpense) =
                //     (list[2] as (double, double));

                final sum = catData.fold<double>(0, (a, b) => a + b.total);

                return GestureDetector(
                  onHorizontalDragEnd: (_) => setState(
                      () => _type = _type == 'expense' ? 'income' : 'expense'),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 顶部统计文本：总支出/收入 & 平均值
                      _TopTexts(
                        scope: _scope,
                        isExpense: _type == 'expense',
                        total: sum,
                        avg: _computeAverage(seriesRaw, _scope),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: _PieChart(
                          data: catData,
                          total: sum,
                          labelThreshold: _pieLabelThreshold,
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

// 移除旧的分段控件实现（已用胶囊分段替换）

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
      case 'week':
        avgLabel = '日均';
        break;
      case 'year':
        avgLabel = '月均';
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

// 胶囊分段（周/月/年）
class _CapsuleSwitcher extends StatelessWidget {
  final String value; // 'week' | 'month' | 'year'
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
          seg('week', '周'),
          const SizedBox(width: 4),
          seg('month', '月'),
          const SizedBox(width: 4),
          seg('year', '年'),
        ],
      ),
    );
  }
}

// 周序条（… 上周 本周）
class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  int _isoWeekNumber(DateTime date) {
    // 基于 ISO 周数的简化实现
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final diff = thursday.difference(firstThursday);
    return 1 + (diff.inDays / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisWeek = _isoWeekNumber(now).clamp(1, 53);
    int wrap(int w) {
      // 1..53 循环
      if (w < 1) return 53 + w;
      if (w > 53) return w - 53;
      return w;
    }

    final weeks = [wrap(thisWeek - 4), wrap(thisWeek - 3), wrap(thisWeek - 2)];

    Widget chip(String text,
        {bool filled = false,
        EdgeInsets padding =
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6)}) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: padding,
        decoration: BoxDecoration(
          color: filled ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12.withOpacity(0.2)),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: filled ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final w in weeks) chip('$w周'),
          chip('上周'),
          chip('本周', filled: true),
        ],
      ),
    );
  }
}
