import 'package:flutter/material.dart';

import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../utils/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart' show DashboardWidgetData;
import '../widget_spec.dart' show HWSize;
import 'recent_view.dart' show RecentWidgetRows;
import 'widget_view_style.dart';

/// 大号仪表盘。桌面原生热区将上方 82% 打开明细，底部 18% 打开支出记账。
class DashboardView extends StatelessWidget {
  /// 仪表盘只在大号规格中注册。
  final HWSize size;

  final DashboardWidgetData data;

  /// 账本自身币种,用于本月支出/收入格式化;同时作为最近交易行金额的兜底
  /// 币种(交易自身 currencyCode 缺失时用它,见
  /// `RecentTransactionRow.defaultCurrency` 文档)。
  final String defaultCurrency;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  /// 顶部本月收支沿用速览组件的本地化标签。
  final String monthExpenseLabel;
  final String monthIncomeLabel;

  /// "最近交易"区块标题。
  final String recentLabel;

  final String uncategorizedLabel;

  /// 最近交易为空时的占位文案。
  final String noTransactionsLabel;

  /// 「记一笔」按钮文案。
  final String quickAddLabel;

  final double width;
  final double height;

  const DashboardView({
    super.key,
    this.size = HWSize.large,
    required this.data,
    required this.defaultCurrency,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.monthExpenseLabel = '本月支出',
    this.monthIncomeLabel = '本月收入',
    this.recentLabel = '最近交易',
    this.uncategorizedLabel = '未分类',
    this.noTransactionsLabel = '暂无交易',
    this.quickAddLabel = '记一笔',
    this.titleLabel = '本月概览',
    this.periodLabel,
    this.referenceDate,
    this.trendLabel = '净资产趋势',
    this.trendRangeLabel = '近 30 天',
    required this.width,
    required this.height,
  });

  /// 当前图片语言的「本月概览」标题。
  final String titleLabel;

  final String? periodLabel;
  /// 交易行按这一天判断显示时间还是日期。
  final DateTime? referenceDate;
  final String trendLabel, trendRangeLabel;

  String _money(double value) =>
      '${getCurrencySymbol(defaultCurrency)}${formatMoneyCompact(value)}';

  @override
  Widget build(BuildContext context) {
    final trend = data.netWorthTrend;
    // An empty database may still return one zero-valued point per day.
    final hasTrend = trend.length >= 2 &&
        trend.any((point) =>
            point.assets != 0 || point.liabilities != 0 || point.net != 0);
    final meta = [
      if (periodLabel?.isNotEmpty == true) periodLabel!,
      defaultCurrency
    ].join(' · ');
    return WidgetCardSurface(
      width: width,
      height: height,
      dark: dark,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WidgetCardHeading(
                      icon: Icons.insights_outlined,
                      title: titleLabel,
                      meta: meta,
                      dark: dark),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                        child: _metric(monthExpenseLabel,
                            data.glance.monthExpenseTotal, 31)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _metric(monthIncomeLabel,
                            data.glance.monthIncomeTotal, 18)),
                  ]),
                  if (hasTrend) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: Text(trendLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: widgetTextSecondary(dark),
                                  fontSize: 10))),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(trendRangeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: widgetTextSecondary(dark),
                                      fontSize: 10)))),
                    ]),
                    const SizedBox(height: 4),
                    SizedBox(
                        height: 33,
                        child: WidgetSparkline(
                          values: [for (final point in trend) point.net],
                          color: themeColor,
                          filled: true,
                        )),
                  ],
                  const SizedBox(height: 10),
                  Container(height: 1, color: widgetDivider(dark)),
                  const SizedBox(height: 8),
                  Text(recentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: widgetTextPrimary(dark))),
                  const SizedBox(height: 2),
                  Expanded(
                      child: RecentWidgetRows(
                    items: data.recent.take(2).toList(),
                    defaultCurrency: defaultCurrency,
                    referenceDate: referenceDate,
                    uncategorizedLabel: uncategorizedLabel,
                    emptyLabel: noTransactionsLabel,
                    themeColor: themeColor,
                    redForIncome: redForIncome,
                    dark: dark,
                  )),
                ]),
          ),
        ),
        Container(
          key: const ValueKey('dashboard-add-expense'),
          height: height * .18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: themeColor,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(22))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded,
                size: 18, color: widgetOnAccent(themeColor)),
            const SizedBox(width: 6),
            Flexible(
                child: Text(quickAddLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: widgetOnAccent(themeColor),
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }

  Widget _metric(String label, double value, double fontSize) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  color: widgetTextSecondary(dark))),
          const SizedBox(height: 4),
          WidgetCardMoney(
              amount: _money(value), dark: dark, fontSize: fontSize),
        ],
      );
}
