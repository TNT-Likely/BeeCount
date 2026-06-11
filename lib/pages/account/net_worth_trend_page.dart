import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/net_worth_trend_utils.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/charts/line_chart.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';

/// 趋势线维度:净资产 / 总资产 / 总负债。
enum _TrendLine { net, assets, liabilities }

/// 时间范围:近 3/6/12 个月,或全部。
enum _TrendRange { m3, m6, m12, all }

/// 全屏净值趋势页:范围切换 + 线切换 + 期初→期末涨跌摘要 + 自研折线图 + 多币种脚注。
class NetWorthTrendPage extends ConsumerStatefulWidget {
  const NetWorthTrendPage({super.key});

  @override
  ConsumerState<NetWorthTrendPage> createState() => _NetWorthTrendPageState();
}

class _NetWorthTrendPageState extends ConsumerState<NetWorthTrendPage> {
  _TrendLine _line = _TrendLine.net;
  _TrendRange _range = _TrendRange.m12;

  ({DateTime start, DateTime end}) _rangeDates(DateTime? earliest) {
    final now = trendTodayAnchor();
    switch (_range) {
      case _TrendRange.m3:
        return (start: DateTime(now.year, now.month - 2, 1), end: now);
      case _TrendRange.m6:
        return (start: DateTime(now.year, now.month - 5, 1), end: now);
      case _TrendRange.m12:
        return (start: DateTime(now.year, now.month - 11, 1), end: now);
      case _TrendRange.all:
        // 「全部」从第一笔交易当月初算起；无交易时退回近 12 月（避免空区间把图拉乱）。
        final base = earliest ?? DateTime(now.year, now.month - 11, 1);
        return (start: DateTime(base.year, base.month, 1), end: now);
    }
  }

  double _pick(
      ({DateTime date, double assets, double liabilities, double net}) e) {
    switch (_line) {
      case _TrendLine.net:
        return e.net;
      case _TrendLine.assets:
        return e.assets;
      case _TrendLine.liabilities:
        return e.liabilities;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final hide = ref.watch(hideAmountsProvider);
    final earliest = ref.watch(earliestTransactionDateProvider).valueOrNull;
    final dates = _rangeDates(earliest);
    final seriesAsync = ref.watch(
        netWorthTrendSeriesProvider((startDate: dates.start, endDate: dates.end)));
    final multi =
        (ref.watch(usedCurrenciesProvider).valueOrNull?.length ?? 1) > 1;

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
              title: l10n.netWorthTrendTitle, showBack: true, compact: true),
          Expanded(
            child: seriesAsync.when(
              data: (daily) {
                if (daily.length < 2) {
                  return Center(
                    child: Text(
                      l10n.commonEmpty,
                      style:
                          TextStyle(color: BeeTokens.textTertiary(context)),
                    ),
                  );
                }
                final monthly = downsampleMonthly(daily);
                final values = monthly.map(_pick).toList();
                final first = values.first;
                final last = values.last;
                final delta = last - first;
                final pct = first != 0 ? (delta / first.abs() * 100) : 0.0;
                return ListView(
                  padding: EdgeInsets.all(12.0.scaled(context, ref)),
                  children: [
                    _rangeSelector(l10n, primary),
                    SizedBox(height: 8.0.scaled(context, ref)),
                    _lineSelector(l10n, primary),
                    SizedBox(height: 12.0.scaled(context, ref)),
                    // 期初 → 期末涨跌摘要
                    Row(
                      children: [
                        AmountText(
                          value: first,
                          signed: false,
                          showCurrency: true,
                          style: TextStyle(
                              fontSize: 13,
                              color: BeeTokens.textTertiary(context)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.0.scaled(context, ref)),
                          child: Icon(Icons.arrow_forward,
                              size: 14,
                              color: BeeTokens.iconTertiary(context)),
                        ),
                        AmountText(
                          value: last,
                          signed: false,
                          showCurrency: true,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: BeeTokens.textPrimary(context)),
                        ),
                        const Spacer(),
                        // 期初净值为 0 时 pct 无意义(会显示误导的「+0.0%」),不显。
                        if (!hide && first != 0)
                          Text(
                            '${delta >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: delta >= 0
                                    ? BeeTokens.incomeColor(context, ref)
                                    : BeeTokens.expenseColor(context, ref)),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.0.scaled(context, ref)),
                    SizedBox(
                      height: 240.0.scaled(context, ref),
                      child: LineChart(
                        values: values,
                        xLabels: monthly
                            .map((e) =>
                                '${e.date.year % 100}/${e.date.month}')
                            .toList(),
                        highlightIndex: values.length - 1,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        showHint: false,
                        hideAmounts: hide,
                        themeColor: primary,
                        whiteBg: !BeeTokens.isDark(context),
                        isDark: BeeTokens.isDark(context),
                        showGrid: true,
                        showDots: true,
                        annotate: true,
                      ),
                    ),
                    if (multi)
                      Padding(
                        padding:
                            EdgeInsets.only(top: 12.0.scaled(context, ref)),
                        child: Text(
                          l10n.netWorthTrendMultiCurrencyNote,
                          style: TextStyle(
                              fontSize: 11,
                              color: BeeTokens.textTertiary(context)),
                        ),
                      ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  l10n.commonError,
                  style: TextStyle(color: BeeTokens.textTertiary(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeSelector(AppLocalizations l10n, Color primary) =>
      _TrendChipSelector<_TrendRange>(
        values: _TrendRange.values,
        selected: _range,
        primaryColor: primary,
        labelOf: (r) => switch (r) {
          _TrendRange.m3 => l10n.netWorthTrend3M,
          _TrendRange.m6 => l10n.netWorthTrend6M,
          _TrendRange.m12 => l10n.netWorthTrend12M,
          _TrendRange.all => l10n.netWorthTrendAll,
        },
        onSelected: (r) => setState(() => _range = r),
      );

  Widget _lineSelector(AppLocalizations l10n, Color primary) =>
      _TrendChipSelector<_TrendLine>(
        values: _TrendLine.values,
        selected: _line,
        primaryColor: primary,
        labelOf: (ln) => switch (ln) {
          _TrendLine.net => l10n.netWorthTrendLineNet,
          _TrendLine.assets => l10n.netWorthTrendLineAssets,
          _TrendLine.liabilities => l10n.netWorthTrendLineLiabilities,
        },
        onSelected: (ln) => setState(() => _line = ln),
      );
}

/// 净值趋势页的标签选择器（范围维度 / 线维度共用）：主题色高亮选中，泛型适配不同枚举。
class _TrendChipSelector<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final Color primaryColor;

  const _TrendChipSelector({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(labelOf(v)),
              selected: selected == v,
              // 彻底主题色化：去掉 Material 默认的紫色 checkmark 与选中底色，
              // 未选中＝透明底/灰边/灰字，选中＝主题色边+淡主题色底+主题色字。
              showCheckmark: false,
              backgroundColor: Colors.transparent,
              selectedColor: primaryColor.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontSize: 13,
                color: selected == v
                    ? primaryColor
                    : BeeTokens.textSecondary(context),
                fontWeight: selected == v ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color:
                    selected == v ? primaryColor : BeeTokens.border(context),
              ),
              onSelected: (_) => onSelected(v),
            ),
        ],
      );
}
