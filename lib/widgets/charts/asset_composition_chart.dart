import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';
import '../biz/biz.dart';

/// 资产构成饼图
class AssetCompositionChart extends ConsumerStatefulWidget {
  final List<({String type, double totalBalance})> data;

  /// embedded 模式下不渲染外层 SectionCard 和标题
  final bool embedded;

  const AssetCompositionChart({
    super.key,
    required this.data,
    this.embedded = false,
  });

  @override
  ConsumerState<AssetCompositionChart> createState() =>
      _AssetCompositionChartState();
}

class _AssetCompositionChartState extends ConsumerState<AssetCompositionChart> {
  int _touchedIndex = -1;
  static const _maxSlices = 8;

  List<({String type, double value, Color color})> _buildSlices() {
    final primaryColor = ref.watch(primaryColorProvider);
    // 过滤出正值项（资产构成只看正余额）
    final positiveItems = widget.data.where((d) => d.totalBalance > 0).toList()
      ..sort((a, b) => b.totalBalance.compareTo(a.totalBalance));

    final slices = <({String type, double value, Color color})>[];
    double otherTotal = 0;

    for (var i = 0; i < positiveItems.length; i++) {
      final item = positiveItems[i];
      if (slices.length < _maxSlices) {
        slices.add((
          type: item.type,
          value: item.totalBalance,
          color: getColorForAccountType(item.type, primaryColor),
        ));
      } else {
        otherTotal += item.totalBalance;
      }
    }

    if (otherTotal > 0) {
      slices.add((
        type: '_other_',
        value: otherTotal,
        color: BeeTokens.textTertiary(context),
      ));
    }

    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final positiveSum = widget.data
        .where((d) => d.totalBalance > 0)
        .fold(0.0, (sum, d) => sum + d.totalBalance);

    if (widget.data.isEmpty || positiveSum <= 0) {
      return const SizedBox.shrink();
    }

    final slices = _buildSlices();
    if (slices.isEmpty) return const SizedBox.shrink();

    final hasSelection = _touchedIndex >= 0 && _touchedIndex < slices.length;
    final selectedSlice = hasSelection ? slices[_touchedIndex] : null;

    final chartContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
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
                        }
                        return;
                      }
                      final idx = response.touchedSection!.touchedSectionIndex;
                      if (idx != _touchedIndex) {
                        setState(() => _touchedIndex = idx);
                      }
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: List.generate(slices.length, (i) {
                    final s = slices[i];
                    final pct = (s.value / positiveSum * 100);
                    final isTouched = i == _touchedIndex;
                    return PieChartSectionData(
                      color: s.color,
                      value: s.value,
                      title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
                      radius: isTouched ? 48 : 40,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedSlice != null
                        ? (selectedSlice.type == '_other_'
                            ? l10n.commonOther
                            : getAccountTypeLabel(context, selectedSlice.type))
                        : l10n.assetComposition,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BeeTokens.textTertiary(context),
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AmountText(
                    value: selectedSlice?.value ?? positiveSum,
                    signed: false,
                    decimals: 0,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: slices.map((s) {
            final pct = (s.value / positiveSum * 100).toStringAsFixed(1);
            final displayName = s.type == '_other_'
                ? l10n.commonOther
                : getAccountTypeLabel(context, s.type);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
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
                const SizedBox(width: 2),
                Text(
                  '$pct%',
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

    if (widget.embedded) {
      return chartContent;
    }

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12.0.scaled(context, ref)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.assetComposition,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textPrimary(context),
              ),
            ),
            SizedBox(height: 12.0.scaled(context, ref)),
            chartContent,
          ],
        ),
      ),
    );
  }
}
