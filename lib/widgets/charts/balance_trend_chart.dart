import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';
import '../biz/section_card.dart';
import 'line_chart.dart';

/// 余额趋势图（账户详情页用）
class BalanceTrendChart extends ConsumerStatefulWidget {
  final List<({DateTime date, double balance})> data;

  /// embedded 模式下不渲染外层 SectionCard 和标题
  final bool showCard;

  const BalanceTrendChart({
    super.key,
    required this.data,
    this.showCard = true,
  });

  @override
  ConsumerState<BalanceTrendChart> createState() => _BalanceTrendChartState();
}

class _BalanceTrendChartState extends ConsumerState<BalanceTrendChart> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    if (widget.data.isEmpty) return const SizedBox.shrink();

    // 生成 values 和 xLabels
    final values = widget.data.map((d) => d.balance).toList();
    final xLabels = widget.data.map((d) {
      return '${d.date.month}/${d.date.day}';
    }).toList();

    // 对于长数据，仅显示部分标签
    final displayLabels = <String>[];
    final step = widget.data.length > 14
        ? (widget.data.length ~/ 7)
        : (widget.data.length > 7 ? 2 : 1);
    for (int i = 0; i < xLabels.length; i++) {
      if (i % step == 0 || i == xLabels.length - 1) {
        displayLabels.add(xLabels[i]);
      } else {
        displayLabels.add('');
      }
    }

    final chartWidget = SizedBox(
      height: 180.0.scaled(context, ref),
      child: LineChart(
        values: values,
        xLabels: displayLabels,
        highlightIndex: null,
        onSwipeLeft: () {},
        onSwipeRight: () {},
        showHint: false,
        whiteBg: !BeeTokens.isDark(context),
        showGrid: true,
        showDots: widget.data.length <= 30,
        annotate: false,
        themeColor: primaryColor,
        isDark: BeeTokens.isDark(context),
      ),
    );

    if (!widget.showCard) return chartWidget;

    return SectionCard(
      child: Padding(
        padding: EdgeInsets.all(12.0.scaled(context, ref)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountBalanceTrend,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textPrimary(context),
              ),
            ),
            SizedBox(height: 12.0.scaled(context, ref)),
            chartWidget,
          ],
        ),
      ),
    );
  }
}
