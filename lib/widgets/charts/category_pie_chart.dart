import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import '../../data/db.dart' as db;
import '../biz/biz.dart';

/// 饼图用的分类调色板（12 色，覆盖常见分类数量）
const _kPieColors = <Color>[
  Color(0xFF5B8FF9), // 蓝
  Color(0xFF5AD8A6), // 绿
  Color(0xFFF6BD16), // 黄
  Color(0xFFE86452), // 红
  Color(0xFF6DC8EC), // 浅蓝
  Color(0xFF945FB9), // 紫
  Color(0xFFFF9845), // 橙
  Color(0xFF1E9493), // 青
  Color(0xFFFF99C3), // 粉
  Color(0xFF269A99), // 深青
  Color(0xFFBDD2FD), // 淡蓝
  Color(0xFFA0DC2C), // 黄绿
];

/// 分类饼图条目
typedef PieCategoryItem = ({
  int? id,
  String name,
  db.Category? category,
  double total,
  List<
      ({
        int id,
        db.Category category,
        String name,
        double total
      })> subCategories,
});

/// 分类占比饼图
class CategoryPieChart extends ConsumerStatefulWidget {
  final List<PieCategoryItem> data;
  final double sum;

  /// 选中扇区回调，返回分类索引（-1 表示取消选中）
  final ValueChanged<int>? onSectionTap;

  const CategoryPieChart({
    super.key,
    required this.data,
    required this.sum,
    this.onSectionTap,
  });

  @override
  ConsumerState<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends ConsumerState<CategoryPieChart> {
  int _touchedIndex = -1;

  /// 最多显示的扇区数（超出合并为「其他」）
  static const _maxSlices = 8;

  @override
  void didUpdateWidget(CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _touchedIndex = -1;
    }
  }

  /// 将原始分类列表合并为 ≤ _maxSlices 条，多余归入「其他」
  List<({String name, double total, Color color, int originalIndex})>
      _buildSlices() {
    final sorted = List.generate(widget.data.length, (i) => i);
    sorted.sort((a, b) => widget.data[b].total.compareTo(widget.data[a].total));

    final slices =
        <({String name, double total, Color color, int originalIndex})>[];
    double otherTotal = 0;

    for (var i = 0; i < sorted.length; i++) {
      final idx = sorted[i];
      final item = widget.data[idx];
      if (item.total <= 0) continue;

      if (slices.length < _maxSlices) {
        slices.add((
          name: item.name,
          total: item.total,
          color: _kPieColors[slices.length % _kPieColors.length],
          originalIndex: idx,
        ));
      } else {
        otherTotal += item.total;
      }
    }

    if (otherTotal > 0) {
      slices.add((
        name: '_other_',
        total: otherTotal,
        color: BeeTokens.textTertiary(context),
        originalIndex: -1,
      ));
    }

    return slices;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty || widget.sum <= 0) {
      return const SizedBox.shrink();
    }

    final slices = _buildSlices();
    if (slices.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    // 选中扇区的信息（显示在环形中心）
    final hasSelection = _touchedIndex >= 0 && _touchedIndex < slices.length;
    final selectedSlice = hasSelection ? slices[_touchedIndex] : null;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        if (_touchedIndex != -1) {
                          setState(() => _touchedIndex = -1);
                          widget.onSectionTap?.call(-1);
                        }
                        return;
                      }
                      final idx = response.touchedSection!.touchedSectionIndex;
                      if (idx != _touchedIndex) {
                        setState(() => _touchedIndex = idx);
                        if (idx >= 0 && idx < slices.length) {
                          widget.onSectionTap?.call(slices[idx].originalIndex);
                        }
                      }
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: List.generate(slices.length, (i) {
                    final s = slices[i];
                    final pct = (s.total / widget.sum * 100);
                    final isTouched = i == _touchedIndex;
                    return PieChartSectionData(
                      color: s.color,
                      value: s.total,
                      title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
                      radius: isTouched ? 56 : 48,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 13 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
              // 环形中心：显示选中分类的名称和金额，或总金额
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedSlice != null
                        ? (selectedSlice.name == '_other_'
                            ? l10n.commonOther
                            : CategoryUtils.getDisplayName(
                                selectedSlice.name, context))
                        : l10n.analyticsTotalAmount,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BeeTokens.textTertiary(context),
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AmountText(
                    value: selectedSlice?.total ?? widget.sum,
                    signed: false,
                    decimals: 0,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 图例：名称 + 金额 + 百分比
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: slices.map((s) {
            final pct = (s.total / widget.sum * 100).toStringAsFixed(1);
            final displayName = s.name == '_other_'
                ? l10n.commonOther
                : CategoryUtils.getDisplayName(s.name, context);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BeeTokens.textPrimary(context),
                        fontSize: 11,
                      ),
                ),
                const SizedBox(width: 4),
                AmountText(
                  value: s.total,
                  signed: false,
                  decimals: 0,
                  style: TextStyle(
                    fontSize: 11,
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '($pct%)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BeeTokens.textTertiary(context),
                        fontSize: 10,
                      ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
