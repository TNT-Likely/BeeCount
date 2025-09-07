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
  String _scope = 'month'; // month/year/all
  String _type = 'expense'; // expense/income，左右滑切换

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
      start = DateTime(2000, 1, 1);
      end = DateTime(2100, 1, 1);
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
            ),
          ),
          Expanded(
            child: FutureBuilder<List<({String name, double total})>>(
              future: repo.totalsByCategory(
                  ledgerId: ledgerId, type: _type, start: start, end: end),
              builder: (context, snap) {
                final data = snap.data ?? [];
                final sum = data.fold<double>(0, (a, b) => a + b.total);
                return GestureDetector(
                  onHorizontalDragEnd: (d) {
                    setState(() =>
                        _type = _type == 'expense' ? 'income' : 'expense');
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SizedBox(
                        height: 220,
                        child: _PieChart(data: data, total: sum),
                      ),
                      const SizedBox(height: 12),
                      Text('分类排行',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final item in data)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          trailing: Text(item.total.toStringAsFixed(2)),
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
  const _ScopeSwitcher({
    required this.scope,
    required this.onScope,
    required this.type,
    required this.onSwipeType,
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
              ButtonSegment(value: 'month', label: Text('月视角')),
              ButtonSegment(value: 'year', label: Text('年视角')),
              ButtonSegment(value: 'all', label: Text('总视角')),
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
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final List<({String name, double total})> data;
  final double total;
  const _PieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PiePainter(data: data, total: total),
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
  _PiePainter({required this.data, required this.total});

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

  Color _colorFor(String name) {
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
      paint.color = _colorFor(v.name);
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(arcRect, start, sweep, true, paint);

      // 标签（>5% 才绘制，避免拥挤）：名称 + 百分比
      if (pct >= 0.05) {
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
    return oldDelegate.data != data || oldDelegate.total != total;
  }
}
